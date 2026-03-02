from typing import Any, Dict, Type
from shared.apps.base import BaseApp
from shared.apps.generic import GenericHelmApp
from shared.utils.schemas import AppModel

# Import specialized implementations
from shared.apps.impl.external_secrets import ExternalSecretsApp
# from shared.apps.impl.authentik import AuthentikApp # If we created it

class AppFactory:
    """Factory to create specialized or generic app instances from AppModel."""
    
    _specialized_map: Dict[str, Type[BaseApp]] = {
        "external-secrets": ExternalSecretsApp,
    }
    
    @classmethod
    def create(cls, model: AppModel) -> BaseApp:
        """Create an app instance based on the model name or other properties."""
        app_class = cls._specialized_map.get(model.name, GenericHelmApp)
        return app_class(model)
