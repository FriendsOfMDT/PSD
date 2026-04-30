import clsx from 'clsx';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import Heading from '@theme/Heading';

import styles from './index.module.css';

const features = [
  {
    title: 'Modern PowerShell Framework',
    description:
      'PSD replaces legacy VBScript MDT automation with native PowerShell scripts and modules, providing a fully modern deployment pipeline.',
  },
  {
    title: 'HTTPS-Based Deployments',
    description:
      'Deploy Windows over IIS/HTTPS without requiring VPN or direct SMB access. Ideal for cloud, remote, and zero-touch deployment scenarios.',
  },
  {
    title: 'BranchCache & P2P Support',
    description:
      'Leverage 2Pint Software\'s OSD Toolkit integration to enable BITS-based peer-to-peer content distribution for efficient network usage.',
  },
  {
    title: 'Simplified Task Sequences',
    description:
      'PSD modernizes and streamlines MDT task sequences while retaining full compatibility with the MDT Deployment Workbench and tooling.',
  },
  {
    title: 'Advanced Wizard UI',
    description:
      'The new PSD Wizard includes panes for Intune enrollment, device role selection, language, and more — fully customizable via themes.',
  },
  {
    title: 'Extensible & Open Source',
    description:
      'MIT-licensed and community-driven. Extend PSD with UserExitScripts, custom modules, RestPS integration, and plugin support.',
  },
];

function Feature({ title, description }) {
  return (
    <div className={clsx('col col--4')}>
      <div className="text--center padding-horiz--md padding-vert--md">
        <Heading as="h3">{title}</Heading>
        <p>{description}</p>
      </div>
    </div>
  );
}

function HomepageHeader() {
  const { siteConfig } = useDocusaurusContext();
  return (
    <header className={clsx('hero hero--primary', styles.heroBanner)}>
      <div className="container">
        <Heading as="h1" className="hero__title">
          {siteConfig.title}
        </Heading>
        <p className="hero__subtitle">{siteConfig.tagline}</p>
        <div className={styles.buttons}>
          <Link
            className="button button--secondary button--lg"
            to="/docs/intro">
            Get Started →
          </Link>
          <Link
            className="button button--outline button--secondary button--lg"
            href="https://github.com/FriendsOfMDT/PSD">
            GitHub
          </Link>
        </div>
        <div className={styles.badgeRow}>
          <img alt="GitHub stars" src="https://img.shields.io/github/stars/FriendsOfMDT/PSD?style=social" />
          <img alt="License" src="https://img.shields.io/github/license/FriendsOfMDT/PSD" />
          <img alt="Language" src="https://img.shields.io/github/languages/top/FriendsOfMDT/PSD" />
        </div>
      </div>
    </header>
  );
}

export default function Home() {
  return (
    <Layout
      title="Home"
      description="PowerShell Deployment (PSD) — A modern PowerShell-based extension for Microsoft Deployment Toolkit enabling HTTPS, BranchCache, and Zero-Touch OS deployments.">
      <HomepageHeader />
      <main>
        <section className={styles.features}>
          <div className="container">
            <div className="row">
              {features.map((props, idx) => (
                <Feature key={idx} {...props} />
              ))}
            </div>
          </div>
        </section>

        <section className={styles.quickStart}>
          <div className="container">
            <div className="row">
              <div className="col col--8 col--offset-2">
                <Heading as="h2" className="text--center">Quick Start</Heading>
                <p className="text--center">
                  Install PSD onto a new MDT deployment share in three steps.
                </p>
                <div className={styles.codeBlock}>
                  <pre>
                    <code>{`# 1. Clone the repository
git clone https://github.com/FriendsOfMDT/PSD.git

# 2. Open an elevated PowerShell prompt and run the installer
.\\Install-PSD.ps1 -psDeploymentFolder "D:\\PSD" -psDeploymentShare "dep-psd$"

# 3. Configure IIS for HTTPS deployments (see IIS Configuration Guide)`}
                    </code>
                  </pre>
                </div>
                <div className="text--center" style={{ marginTop: '1.5rem' }}>
                  <Link
                    className="button button--primary button--lg"
                    to="/docs/getting-started/installation">
                    Full Installation Guide
                  </Link>
                </div>
              </div>
            </div>
          </div>
        </section>

        <section className={styles.docLinks}>
          <div className="container">
            <Heading as="h2" className="text--center">Documentation</Heading>
            <div className="row">
              {[
                { title: 'Prerequisites', desc: 'Software, accounts, and hardware needed before installing.', link: '/docs/getting-started/prerequisites' },
                { title: 'Installation Guide', desc: 'Step-by-step instructions for new installs and upgrades.', link: '/docs/getting-started/installation' },
                { title: 'Configuration', desc: 'Bootstrap.ini, CustomSettings.ini, and PSD Wizard setup.', link: '/docs/configuration/bootstrap-ini' },
                { title: 'Scripts Reference', desc: 'Full reference for all PSD task sequence scripts.', link: '/docs/scripts/scripts-reference' },
                { title: 'Deployment Scenarios', desc: 'Supported transports: UNC, HTTP, HTTPS, BranchCache.', link: '/docs/deployment/scenarios' },
                { title: 'FAQ', desc: 'Answers to the most common questions about PSD.', link: '/docs/reference/faq' },
              ].map(({ title, desc, link }) => (
                <div key={title} className="col col--4 margin-vert--md">
                  <div className={clsx('card', styles.docCard)}>
                    <div className="card__header">
                      <Heading as="h3">{title}</Heading>
                    </div>
                    <div className="card__body">
                      <p>{desc}</p>
                    </div>
                    <div className="card__footer">
                      <Link className="button button--primary button--block" to={link}>
                        Read More
                      </Link>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </section>
      </main>
    </Layout>
  );
}
