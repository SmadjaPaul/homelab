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
      label: 'Architecture',
      collapsed: false,
      items: [
        'architecture/overview',
        'architecture/diagrams',
        'architecture/network',
        'architecture/security',
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
      label: 'Services',
      items: [
        'services/overview',
        'services/monitoring',
        'services/identity',
        'services/backup',
      ],
    },
    {
      type: 'category',
      label: 'Guides',
      items: [
        'guides/getting-started',
        'guides/add-service',
        'guides/secrets-management',
        'guides/disaster-recovery',
      ],
    },
  ],
};

export default sidebars;
