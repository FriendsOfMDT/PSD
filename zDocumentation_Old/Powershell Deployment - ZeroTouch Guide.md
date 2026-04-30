# Zero Touch Deployment with PSD

## Prerequisites

Ensure you have followed the PSD installation guides.

## ZeroTouch

To perform do a ZeroTouch deployment with latest PSD release, you must follow these steps:

1. Edit `Control\CustomSettings.ini` and include these properties:

   ```ini
   SkipBDDWelcome=YES; or SkipPSDWelcome=YES
   SkipDeployReadiness=YES
   SkipTaskSequence=YES
   SkipDiskSelection=YES
   SkipDomainMembership=YES
   SkipComputerName=YES
   SkipRoleSelection=YES
   SkipIntuneGroup=YES
   SkipAdminPassword=YES
   SkipLocaleSelection=YES
   SkipTimeZone=YES
   SkipApplications=YES
   SkipSummary=YES
   SkipPSDWizardSplashScreen=YES
   ```

   If you don't include `SkipPSDWizardSplashScreen=YES` you will get this:

   ![image](https://github.com/user-attachments/assets/9ef642ab-33df-4da3-9759-c404e134cb7e)

   However the PSD wizard will get bypassed and continue the task sequence.

2. The next step, of course, is to make sure you set the correct items such as

   - TaskSequenceID
   - ComputerName
   - DomainJoin or Workgroup
   - Admin Password
   - Applications (optional)
   - Locale and Timezone

## Known Issues

- Currently there is no property to set a default value for the two new pages: _IntuneGroup_ and _DeviceRole_. You must use the wizard to set it for now.
- In the PSDWizardGuide, it mentions _SkipWelcome_ which is a typo and shouldn't be in there.

## TIP

- Do a `diskpart clean` or use the new PrestartMenu to wipe the disk prior to testing these settings and it should work. Send us feedback on this.

## Troubleshooting

 - Read through the [Latest Release Setup Guide](./PowerShell%20Deployment%20-%20Latest%20Release%20Setup%20Guide.md)