import unittest
from shared.utils.schemas import AppModel, ExposureMode, AppCategory, AppTier
from shared.apps.adapters import get_adapter


class TestV2Adapters(unittest.TestCase):
    def test_nextcloud_adapter_db_injection(self):
        """Verify NextcloudAdapter properly injects DB settings for the official chart."""
        model = AppModel(
            name="nextcloud",
            namespace="productivity",
            mode=ExposureMode.PROTECTED,
            category=AppCategory.PROTECTED,
            tier=AppTier.STANDARD,
            hostname="cloud.example.com",
            database={"local": True},
            helm={
                "chart": "nextcloud",
                "repo": "https://nextcloud.github.io/helm/",
                "version": "6.0.0",
                "values": {"nextcloud": {"host": "cloud.example.com"}},
            },
        )
        adapter = get_adapter(model)
        values = adapter.get_final_values()

        # Nextcloud chart specific mappings
        # After refactor: all apps use shared CNPG cluster
        self.assertFalse(values.get("internalDatabase", {}).get("enabled", True))
        self.assertEqual(values.get("externalDatabase", {}).get("type"), "postgresql")
        self.assertTrue(
            values.get("externalDatabase", {})
            .get("host")
            .endswith("cnpg-system.svc.cluster.local")
        )

    def test_paperless_adapter_db_injection(self):
        """Verify PaperlessAdapter properly injects DB and Redis via environment variables."""
        model = AppModel(
            name="paperless-ngx",
            namespace="productivity",
            mode=ExposureMode.PROTECTED,
            category=AppCategory.PROTECTED,
            tier=AppTier.STANDARD,
            database={"local": True},
            helm={
                "chart": "paperless-ngx",
                "repo": "https://paperless-ngx.github.io/helm-charts",
                "version": "1.0.0",
                "values": {},
            },
        )
        adapter = get_adapter(model)
        values = adapter.get_final_values()

        # Paperless-ngx uses environment variables for external DB
        # After refactor: all apps use shared CNPG cluster via env vars
        self.assertEqual(values.get("env", {}).get("PAPERLESS_DBENGINE"), "postgresql")
        self.assertTrue(
            values.get("env", {})
            .get("PAPERLESS_DBHOST", "")
            .endswith("cnpg-system.svc.cluster.local")
        )
        self.assertEqual(values.get("env", {}).get("PAPERLESS_DBPORT"), "5432")

    def test_dify_adapter_complex_logic(self):
        """Verify DifyAdapter handles complex multi-component values."""
        model = AppModel(
            name="dify",
            namespace="ai",
            mode=ExposureMode.PROTECTED,
            category=AppCategory.PROTECTED,
            tier=AppTier.STANDARD,
            database={"local": True},
            helm={
                "chart": "dify",
                "repo": "https://dify-ai.github.io/helm-charts",
                "version": "0.1.0",
                "values": {},
            },
        )
        adapter = get_adapter(model)
        values = adapter.get_final_values()

        # Dify component mappings
        self.assertEqual(values.get("db", {}).get("type"), "postgresql")
        # Ensure we don't accidentally enable internal postgres
        self.assertFalse(values.get("postgresql", {}).get("enabled", True))


if __name__ == "__main__":
    unittest.main()
