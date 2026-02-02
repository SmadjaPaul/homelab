# OCI Identity Provider Pricing

## Free Tier Status

**L'Identity Provider OCI est GRATUIT** ✅

L'Identity Provider OCI (pour la fédération SAML 2.0 / OIDC) est une fonctionnalité de base de gestion d'identité incluse dans le **Free Tier OCI**. Il n'y a **aucun coût** associé à :

- La création d'un Identity Provider
- La configuration de la fédération SAML 2.0 / OIDC
- L'échange de tokens OIDC pour UPST
- Les authentifications via Identity Provider

## Détails

### Services inclus (gratuits)

1. **Identity Provider** : Gratuit
   - Configuration SAML 2.0 / OIDC
   - Mapping de groupes
   - Fédération avec GitHub Actions

2. **IAM Policies** : Gratuit
   - Gestion des politiques d'accès
   - Groupes et utilisateurs

3. **Token Exchange** : Gratuit
   - Échange OIDC → UPST
   - Session tokens temporaires

### Limites Free Tier

- **Identity Providers** : Illimité (dans les limites raisonnables)
- **IAM Groups** : Illimité
- **IAM Policies** : Illimité
- **Authentifications** : Illimité

## Références

- [OCI Free Tier](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier.htm)
- [OCI Identity Provider Documentation](https://docs.oracle.com/en-us/iaas/Content/Identity/Concepts/federation.htm)

## Conclusion

L'implémentation OIDC pour GitHub Actions avec OCI est **100% gratuite** et fait partie du Free Tier OCI. Aucun coût supplémentaire n'est requis.
