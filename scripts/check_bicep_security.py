#!/usr/bin/env python3
"""Check a small, explicit security contract in compiled ARM templates.

This is an offline regression guard, not a cloud configuration audit.
"""

import json
import sys
from pathlib import Path


class BaselineError(ValueError):
    """A compiled resource no longer meets the documented lab baseline."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise BaselineError(message)


def resources_of_type(template: dict, resource_type: str) -> list[dict]:
    return [
        resource for resource in template.get("resources", [])
        if resource.get("type", "").lower() == resource_type.lower()
    ]


def exactly_one(template: dict, resource_type: str) -> dict:
    matches = resources_of_type(template, resource_type)
    require(len(matches) == 1, f"Expected exactly one {resource_type} resource")
    return matches[0]


def check_active_root(template: dict) -> None:
    """The active private-storage phase must not redeploy existing VMs."""
    modules = resources_of_type(template, "Microsoft.Resources/deployments")
    names = {module.get("name") for module in modules}
    require(
        names == {"computeNetworkModule", "storagePrivateEndpointModule"},
        "Active root must deploy only the network and private endpoint modules",
    )
    require(
        not resources_of_type(template, "Microsoft.Compute/virtualMachines"),
        "Active root must not deploy VMs",
    )


def check_compute(template: dict) -> None:
    nic = exactly_one(template, "Microsoft.Network/networkInterfaces")
    configs = nic.get("properties", {}).get("ipConfigurations", [])
    require(bool(configs), "Compute NIC must define a private IP configuration")
    for config in configs:
        props = config.get("properties", {})
        require("publicIPAddress" not in props, "Compute VM NIC must not have a public IP")

    vm = exactly_one(template, "Microsoft.Compute/virtualMachines")
    require(vm.get("identity", {}).get("type") == "SystemAssigned", "VM must use system-assigned identity")
    linux = vm.get("properties", {}).get("osProfile", {}).get("linuxConfiguration", {})
    require(linux.get("disablePasswordAuthentication") is True, "Password-based SSH must stay disabled")


def check_network(template: dict) -> None:
    nsg = exactly_one(template, "Microsoft.Network/networkSecurityGroups")
    rules = nsg.get("properties", {}).get("securityRules", [])
    ssh_rules = [rule for rule in rules if rule.get("name") == "Allow-SSH-From-VNet"]
    require(len(ssh_rules) == 1, "Expected the named private SSH NSG rule")
    props = ssh_rules[0].get("properties", {})
    require(
        props.get("direction") == "Inbound"
        and props.get("access") == "Allow"
        and props.get("protocol") == "Tcp"
        and props.get("destinationPortRange") == "22"
        and props.get("sourceAddressPrefix") == "VirtualNetwork",
        "SSH rule must be inbound TCP/22 restricted to VirtualNetwork",
    )
    # Catch a second permissive SSH rule even if the original rule is unchanged.
    for rule in rules:
        p = rule.get("properties", {})
        port = p.get("destinationPortRange")
        ports = p.get("destinationPortRanges", [])
        ssh_covered = port in {"22", "*"} or "22" in ports or "*" in ports
        if p.get("direction") == "Inbound" and p.get("access") == "Allow" and ssh_covered:
            require(
                p.get("sourceAddressPrefix") == "VirtualNetwork"
                and p.get("protocol") == "Tcp",
                "Every inbound SSH allow rule must be restricted to VirtualNetwork",
            )


def check_storage(template: dict) -> None:
    # This module is retained for historical phases; the active root references
    # an existing Storage account, so this does not attest the live account.
    storage = exactly_one(template, "Microsoft.Storage/storageAccounts")
    props = storage.get("properties", {})
    require(props.get("supportsHttpsTrafficOnly") is True, "Storage must require HTTPS")
    require(props.get("minimumTlsVersion") == "TLS1_2", "Storage must require TLS 1.2")
    require(props.get("allowBlobPublicAccess") is False, "Anonymous Blob access must stay disabled")


def check_private_endpoint(template: dict) -> None:
    endpoint = exactly_one(template, "Microsoft.Network/privateEndpoints")
    connections = endpoint.get("properties", {}).get("privateLinkServiceConnections", [])
    require(
        len(connections) == 1
        and connections[0].get("properties", {}).get("groupIds") == ["blob"],
        "Private endpoint must target the Blob service",
    )
    zone_group = exactly_one(template, "Microsoft.Network/privateEndpoints/privateDnsZoneGroups")
    configs = zone_group.get("properties", {}).get("privateDnsZoneConfigs", [])
    require(
        bool(configs) and all(c.get("properties", {}).get("privateDnsZoneId") for c in configs),
        "Private endpoint must have a private DNS zone group",
    )


def check_directory(directory: Path) -> None:
    for stem, validator in (
        ("azuredeploy", check_active_root),
        ("compute", check_compute),
        ("network", check_network),
        ("storage", check_storage),
        ("storage-private-endpoint", check_private_endpoint),
    ):
        template = json.loads((directory / f"{stem}.json").read_text(encoding="utf-8"))
        validator(template)
        print(f"PASS {stem}: offline security baseline")


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: python3 scripts/check_bicep_security.py <compiled-output-dir>", file=sys.stderr)
        return 2
    try:
        check_directory(Path(sys.argv[1]))
    except (BaselineError, OSError, ValueError, TypeError) as error:
        print(f"FAIL Bicep baseline: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
