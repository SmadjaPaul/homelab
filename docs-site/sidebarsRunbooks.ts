import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  runbooksSidebar: [
    {
      type: 'doc',
      id: 'index',
      label: 'Runbooks',
    },
    {
      type: 'category',
      label: 'Incidents',
      items: [
        'incidents/service-down',
        'incidents/disk-full',
        'incidents/high-cpu',
        'incidents/certificate-expired',
      ],
    },
    {
      type: 'category',
      label: 'Maintenance',
      items: [
        'maintenance/backup-restore',
        'maintenance/upgrade-cluster',
        'maintenance/rotate-secrets',
      ],
    },
  ],
};

export default sidebars;
