"""Negative regression tests for the compiled-template security checks."""

import copy
import json
import unittest
from pathlib import Path

from scripts.check_bicep_security import (
    BaselineError,
    check_active_root,
    check_compute,
    check_network,
    check_private_endpoint,
    check_storage,
)

ROOT = Path(__file__).resolve().parents[1]


def snapshot(name: str) -> dict:
    # Existing checked-in module JSON is used as a fixture here. The CI script
    # separately compiles the CURRENT Bicep files and checks their output.
    return json.loads((ROOT / "modules" / f"{name}.json").read_text(encoding="utf-8"))


class AzureSecurityBaselineTests(unittest.TestCase):
    def test_existing_module_snapshots_meet_the_baseline(self):
        for name, check in (
            ("compute", check_compute),
            ("network", check_network),
            ("storage", check_storage),
            ("storage-private-endpoint", check_private_endpoint),
        ):
            with self.subTest(module=name):
                check(snapshot(name))

    def test_active_root_does_not_redeploy_a_vm(self):
        root = {"resources": [
            {"type": "Microsoft.Resources/deployments", "name": "computeNetworkModule"},
            {"type": "Microsoft.Resources/deployments", "name": "storagePrivateEndpointModule"},
        ]}
        check_active_root(root)
        root["resources"].append({"type": "Microsoft.Compute/virtualMachines", "name": "accidental-vm"})
        with self.assertRaises(BaselineError):
            check_active_root(root)

    def test_rejects_public_vm_nic(self):
        template = copy.deepcopy(snapshot("compute"))
        template["resources"][0]["properties"]["ipConfigurations"][0]["properties"]["publicIPAddress"] = {"id": "public-ip"}
        with self.assertRaisesRegex(BaselineError, "public IP"):
            check_compute(template)

    def test_rejects_password_authentication(self):
        template = copy.deepcopy(snapshot("compute"))
        vm = next(r for r in template["resources"] if r["type"] == "Microsoft.Compute/virtualMachines")
        vm["properties"]["osProfile"]["linuxConfiguration"]["disablePasswordAuthentication"] = False
        with self.assertRaisesRegex(BaselineError, "Password-based SSH"):
            check_compute(template)

    def test_rejects_permissive_ssh_source(self):
        template = copy.deepcopy(snapshot("network"))
        nsg = next(r for r in template["resources"] if r["type"] == "Microsoft.Network/networkSecurityGroups")
        nsg["properties"]["securityRules"][0]["properties"]["sourceAddressPrefix"] = "*"
        with self.assertRaises(BaselineError):
            check_network(template)

    def test_rejects_extra_permissive_ssh_rule(self):
        template = copy.deepcopy(snapshot("network"))
        nsg = next(r for r in template["resources"] if r["type"] == "Microsoft.Network/networkSecurityGroups")
        extra = copy.deepcopy(nsg["properties"]["securityRules"][0])
        extra["name"] = "Allow-SSH-From-Internet"
        extra["properties"]["sourceAddressPrefix"] = "Internet"
        nsg["properties"]["securityRules"].append(extra)
        with self.assertRaises(BaselineError):
            check_network(template)

    def test_rejects_anonymous_blob_access(self):
        template = copy.deepcopy(snapshot("storage"))
        template["resources"][0]["properties"]["allowBlobPublicAccess"] = True
        with self.assertRaisesRegex(BaselineError, "Anonymous Blob"):
            check_storage(template)

    def test_rejects_missing_blob_private_dns_group(self):
        template = copy.deepcopy(snapshot("storage-private-endpoint"))
        template["resources"] = [
            r for r in template["resources"]
            if r["type"] != "Microsoft.Network/privateEndpoints/privateDnsZoneGroups"
        ]
        with self.assertRaises(BaselineError):
            check_private_endpoint(template)


if __name__ == "__main__":
    unittest.main()
