import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  docsSidebar: [
    // ========== Guide utilisateur (utilisateurs finaux)
    {
      type: 'category',
      label: 'Guide utilisateur',
      collapsed: false,
      items: [
        'user-guide/welcome',
        'user-guide/services',
        'user-guide/recommendations',
        'user-guide/limits',
      ],
    },
    // ========== Documentation technique (admin / opération)
    {
      type: 'category',
      label: 'Documentation technique',
      collapsed: false,
      items: [
        'intro',
        {
          type: 'category',
          label: 'Démarrage',
          items: [
            'getting-started/installation',
            'getting-started/configuration',
            'getting-started/first-deploy',
          ],
        },
        {
          type: 'category',
          label: 'Guides',
          items: [
            'guides/add-service',
            'guides/secrets-management',
            'guides/backup-restore',
          ],
        },
        {
          type: 'category',
          label: 'Guides avancés',
          items: [
            'advanced/architecture',
            'advanced/decisions-and-limits',
            'advanced/planning-conclusions',
            'advanced/network',
            'advanced/security',
            'advanced/disaster-recovery',
          ],
        },
        {
          type: 'category',
          label: 'Infrastructure',
          items: [
            'infrastructure/proxmox',
            'infrastructure/oracle-cloud',
            'infrastructure/cloudflare',
            'infrastructure/kubernetes',
          ],
        },
        {
          type: 'category',
          label: 'Runbooks',
          items: [
            'runbooks/overview',
            {
              type: 'category',
              label: 'Incidents',
              items: [
                'runbooks/service-down',
                'runbooks/disk-full',
                'runbooks/high-cpu',
                'runbooks/certificate-expired',
              ],
            },
            {
              type: 'category',
              label: 'Maintenance',
              items: [
                'runbooks/upgrade-cluster',
                'runbooks/rotate-secrets',
              ],
            },
          ],
        },
      ],
    },
  ],
};

export default sidebars;
