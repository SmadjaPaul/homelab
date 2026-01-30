import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  docsSidebar: [
    {
      type: 'doc',
      id: 'intro',
      label: 'Introduction',
    },
    {
      type: 'category',
      label: 'Démarrage',
      collapsed: false,
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
};

export default sidebars;
