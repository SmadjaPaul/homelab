import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

const config: Config = {
  title: 'Homelab Docs',
  tagline: 'Documentation technique du homelab Smadja',
  favicon: 'img/favicon.ico',

  future: {
    v4: true,
  },

  url: 'https://docs.smadja.dev',
  baseUrl: '/',

  organizationName: 'SmadjaPaul',
  projectName: 'homelab',

  onBrokenLinks: 'throw',
  onBrokenMarkdownLinks: 'warn',

  i18n: {
    defaultLocale: 'fr',
    locales: ['fr'],
  },

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          editUrl: 'https://github.com/SmadjaPaul/homelab/tree/main/docs-site/',
          routeBasePath: '/', // Docs at root
        },
        blog: false, // Disable blog
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  plugins: [
    [
      '@docusaurus/plugin-content-docs',
      {
        id: 'runbooks',
        path: 'runbooks',
        routeBasePath: 'runbooks',
        sidebarPath: './sidebarsRunbooks.ts',
      },
    ],
  ],

  themeConfig: {
    image: 'img/homelab-social-card.png',
    colorMode: {
      defaultMode: 'dark',
      respectPrefersColorScheme: true,
    },
    navbar: {
      title: 'Homelab',
      logo: {
        alt: 'Homelab Logo',
        src: 'img/logo.svg',
      },
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'docsSidebar',
          position: 'left',
          label: 'Documentation',
        },
        {
          to: '/runbooks',
          label: 'Runbooks',
          position: 'left',
        },
        {
          href: 'https://status.smadja.dev',
          label: 'Status',
          position: 'right',
        },
        {
          href: 'https://github.com/SmadjaPaul/homelab',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Documentation',
          items: [
            {
              label: 'Architecture',
              to: '/architecture',
            },
            {
              label: 'Services',
              to: '/services',
            },
            {
              label: 'Runbooks',
              to: '/runbooks',
            },
          ],
        },
        {
          title: 'Liens',
          items: [
            {
              label: 'Status Page',
              href: 'https://status.smadja.dev',
            },
            {
              label: 'Feedback',
              href: 'https://feedback.smadja.dev',
            },
            {
              label: 'Homepage',
              href: 'https://home.smadja.dev',
            },
          ],
        },
        {
          title: 'Admin',
          items: [
            {
              label: 'ArgoCD',
              href: 'https://argocd.smadja.dev',
            },
            {
              label: 'Grafana',
              href: 'https://grafana.smadja.dev',
            },
            {
              label: 'GitHub',
              href: 'https://github.com/SmadjaPaul/homelab',
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} Paul Smadja. Built with Docusaurus.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['bash', 'yaml', 'hcl', 'json'],
    },
    algolia: undefined, // Disable Algolia for now
  } satisfies Preset.ThemeConfig,
};

export default config;
