import unittest
import pulumi
from typing import Optional, Tuple, Any, Dict

# Apply mocks before importing components that create resources
class SimpleMocks(pulumi.runtime.Mocks):
    def new_resource(self, args: pulumi.runtime.MockResourceArgs) -> Tuple[Optional[str], dict]:
        return [args.name + "_id", args.inputs]

    def call(self, args: pulumi.runtime.MockCallArgs) -> Tuple[dict, Optional[list[Tuple[str, str]]]]:
        return [{}, None]

pulumi.runtime.set_mocks(SimpleMocks())

import pulumi_kubernetes as k8s
from shared.apps.common.storagebox import StorageBoxManager
from shared.utils.schemas import IdentityUserModel

class TestStorageBoxManager(unittest.TestCase):
    @pulumi.runtime.test
    def test_storagebox_subaccount_creation(self):
        provider = k8s.Provider("test-provider", kubeconfig="test-kubeconfig")
        users = [IdentityUserModel(name="testuser", email="test@example.com", groups=[])]
        
        manager = StorageBoxManager(
            name="test-automation",
            provider=provider,
            storage_box_id=12345,
            users=users,
        )

        def check_subaccounts(args: list):
            sub_accounts = args[0]
            self.assertIn("testuser", sub_accounts)
            sub_account = sub_accounts["testuser"]
            
            # Sub-account validations
            pulumi.Output.all(sub_account.storage_box_id).apply(
                lambda args: self.assertEqual(args[0], 12345)
            )
            
            # Ensure access_settings is being set (which was the cause of the previous API error)
            # In mocks, we check the inputs that were passed to the resource
            def check_settings(settings):
                self.assertIsNotNone(settings, "access_settings should not be None")
                self.assertTrue(settings.get("samba_enabled", False))
                self.assertTrue(settings.get("ssh_enabled", False))
                self.assertTrue(settings.get("webdav_enabled", False))
                self.assertTrue(settings.get("reachable_externally", False))
                
            pulumi.Output.all(sub_account.access_settings).apply(
                lambda args: check_settings(args[0])
            )

        return pulumi.Output.all(manager.sub_accounts).apply(check_subaccounts)

if __name__ == "__main__":
    unittest.main()
