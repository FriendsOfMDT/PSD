// @ts-check

/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  docsSidebar: [
    {
      type: 'doc',
      id: 'intro',
      label: 'Introduction',
    },
    {
      type: 'category',
      label: 'Getting Started',
      collapsed: false,
      items: [
        'getting-started/overview',
        'getting-started/prerequisites',
        'getting-started/installation',
        'getting-started/upgrade',
      ],
    },
    {
      type: 'category',
      label: 'Configuration',
      items: [
        'configuration/bootstrap-ini',
        'configuration/customsettings-ini',
        'configuration/psd-wizard',
      ],
    },
    {
      type: 'category',
      label: 'Scripts & Modules',
      items: [
        'scripts/scripts-reference',
        'scripts/modules-reference',
      ],
    },
    {
      type: 'category',
      label: 'Deployment',
      items: [
        'deployment/scenarios',
        'deployment/iis-setup',
        'deployment/branchwcache',
        'deployment/zero-touch',
      ],
    },
    {
      type: 'category',
      label: 'Advanced Topics',
      items: [
        'advanced/debugging-logging',
        'advanced/driver-packaging',
        'advanced/security',
        'advanced/user-exit-scripts',
        'advanced/restps',
      ],
    },
    {
      type: 'category',
      label: 'Reference',
      items: [
        'reference/supported-platforms',
        'reference/faq',
        'reference/psd-vs-mdt',
        'reference/changelog',
      ],
    },
  ],
};

export default sidebars;
