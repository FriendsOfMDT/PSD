// @ts-check
// `@type` JSDoc annotations allow editor autocompletion and type checking
// (when paired with `@ts-check`).
// There are various equivalent ways to declare your Docusaurus config.
// See: https://docusaurus.io/docs/api/docusaurus-config

import { themes as prismThemes } from 'prism-react-renderer';

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'PowerShell Deployment (PSD)',
  tagline: 'A modern, PowerShell-based extension for Microsoft Deployment Toolkit',
  favicon: 'img/favicon.ico',

  // Set the production URL of your site here
  url: 'https://FriendsOfMDT.github.io/',
  // Set the /<baseUrl>/ pathname under which your site is served
  baseUrl: '/PSD/',
  staticDirectories: ['static'],
  // GitHub pages deployment config.
  organizationName: 'FriendsOfMDT',
  projectName: 'psd',

  onBrokenLinks: 'throw',
  onBrokenMarkdownLinks: 'warn',

  // Even if you don't use internationalization, you can use this field to set
  // useful metadata like html lang.
  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          sidebarPath: './sidebars.js',
          path: '../Documentation',
          editUrl: 'https://github.com/FriendsOfMDT/PSD/edit/master/',
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      image: 'img/psd-social-card.png',
      navbar: {
        title: 'PowerShell Deployment',
        logo: {
          alt: 'PSD Logo',
          src: 'img/powershell.png',
          srcDark: 'img/powershell_dark.png',
        },
        items: [
          {
            type: 'docSidebar',
            sidebarId: 'docsSidebar',
            position: 'left',
            label: 'Documentation',
          },
          {
            href: 'https://github.com/FriendsOfMDT/PSD',
            label: 'GitHub',
            position: 'right',
          },
        ],
      },
      footer: {
        style: 'dark',
        links: [
          {
            title: 'Docs',
            items: [
              { label: 'Introduction', to: '/docs/intro' },
              { label: 'Installation', to: '/docs/getting-started/installation' },
              { label: 'Toolkit Reference', to: '/docs/scripts/scripts-reference' },
            ],
          },
          {
            title: 'Community',
            items: [
              {
                label: 'GitHub Issues',
                href: 'https://github.com/FriendsOfMDT/PSD/issues',
              },
              {
                label: 'GitHub Discussions',
                href: 'https://github.com/FriendsOfMDT/PSD/discussions',
              },
            ],
          },
          {
            title: 'More',
            items: [
              {
                label: 'GitHub',
                href: 'https://github.com/FriendsOfMDT/PSD',
              },
              {
                label: 'Contributing',
                href: 'https://github.com/FriendsOfMDT/PSD/blob/master/CONTRIBUTING.md',
              },
            ],
          },
        ],
        copyright: `Copyright © ${new Date().getFullYear()} Friends of MDT. Built with Docusaurus. MIT License.`,
      },
      prism: {
        theme: prismThemes.github,
        darkTheme: prismThemes.dracula,
        additionalLanguages: ['powershell', 'ini', 'bash'],
      },
      colorMode: {
        defaultMode: 'light',
        disableSwitch: false,
        respectPrefersColorScheme: true,
      },
      tableOfContents: {
        minHeadingLevel: 2,
        maxHeadingLevel: 4,
      },
    }),
};

export default config;
