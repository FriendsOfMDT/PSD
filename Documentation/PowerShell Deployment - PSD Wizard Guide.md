# New PSD Wizard Guide

One of the latest features in PSD is the wizard, which closely resembles the classic MDT interface, with a few additional themes available.

## About the wizard

The new wizard is developed using the XAML language, supporting the Windows Presentation Format (WPF), instead of the previous HTA (HTML) format. You can learn more about XAML here.: [XAML Overview](https://learn.microsoft.com/en-us/windows/uwp/xaml-platform/xaml-overview).

## Themes

This new wizard includes two primary themes, both reminiscent of the MDT interface. Themes can be changed via the CustomSettings.ini.

- Native --> Original theme for PSD (Set _PSDWizard=**Native**_ or leave blank)
![nativeui](.images/nativeui.png)

- Classic --> Default theme. Looks and feels like MDT original menu (Set _PSDWizard=**PSDWizardNew**_ and _PSDWizardTheme=**Classic**_)
![psdwizardnewclassic](.images/psdwizardnew_classic.png)

- Dark --> Looks and feels like MDT original menu but dark theme (Set _PSDWizard=**PSDWizardNew**_ and _PSDWizardTheme=**Dark**_)
![psdwizardnewdark](.images/psdwizardnew_dark.png)

> Addtional themes can be found [here](https://github.com/PowerShellCrack/PSDWizardNew_CustomThemes)
## The underlying structure

The wizard's structure is designed to be modular and includes controllable features similar to the original MDT wizard. While it uses the same XML definitions as the original, there are additional XML files for themes, languages, and pages. For more details, see the structure section.

```
DeploymentShare
    |-Tools
        |-Modules
            |-PSDWizardNew
                |--PSDWizardNew.psm1
    |-Scripts
        |--PSDListOfLanguages.xml
        |--PSDListOfTimeZoneIndex.xml
        |-PSDWizardNew
            |--PSDWizard.Initialize.ps1
            |--PSDWizard.Definition_<Language>.xml
            |-Resources
                |--<icons,colors,buttons,etc > in XAML format
            |-Themes
                |--Classic_Theme_Definitions_<Language>.xml
                |--Dark_Theme_Definitions_<Language>.xml
                |-Classic
                    |--Classic-<paneid>-<Language>.xaml
                |-Dark
                    |--Dark-<paneid>-<Language>.xaml

```

> Currently, only **en-US** is supported, but there is potential for additional languages in the future.

## File explanations

- **PSDWizardNew.psm1**: This module is loaded to present the UI. Each page is divided into its respective XAML file. The module references the customsettings.ini for any skips, language, and theme variables, compares these with the definition files (e.g., PSDWizard.Definition_**en-US**.xml and **Classic**\_Theme_Definitions_**en-US**.xml), and then constructs all pages into a single UI.
- **PSDWizard.Initialize.ps1**: This script no longer contains PSDWizard functions (it is not part of the module) but can be used to support additional functions during the wizard process.
- **PSDListOfLanguages.xml**: Used in the UI to display the locale dropdown.
- **PSDListOfTimeZoneIndex.xml**: Used in the UI to display the time zone dropdown.
- **\<Resource\>.xaml files**: These contain the variant theme buttons, icons, and visual dependencies for the UI.
- **\<Theme\>_Theme_Definitions_\<Language\>.xml**: Contains a list of pages (_aka Panes_) each theme can use and their IDs.
- **\<theme\>-\<paneid\>-\<Language\>.xaml**: Contains each page for each theme. For example, in the classic theme, there is a _PSDWizard_Applications_en-US.xaml_ file that defines the layout of the applications page in English.

## Supported variables in _Bootstrap.ini_

- **SkipBDDWelcome**: YES or NO. Toggles the Welcome splash screen.

## Supported variables in _CustomSetting.ini_

- **OSDComputerName**: Even though this is a standard MDT variable, the PSD wizard supports some dynamic values:
  - **_%SERIALNUMBER%_**: Replaced with the device's serial number.
  - **_%SERIAL%_**: Replaced with the device's serial number.
  - **_%SERIAL:\<NUM\>%_**: Replaced with the last **num**bers of the serial number (e.g., %SERIAL:7%).
  - **_%\<NUM\>:SERIAL%_**: Replaced with the first **num**bers of the serial number (e.g., %7:SERIAL%).
  - **_%RAND:\<NUM\>%_**: Replaced with an alphanumeric character of **num**bers (e.g., %RAND:7%).

Here are standard properties that can be set:

- **SkipBDDWelcome**: YES or NO. Toggles the Welcome splash screen.
- **SkipWelcome**: YES or NO. Toggles the Welcome splash screen (same as _SkipBDDWelcome_).
- **SkipTaskSequence**: YES or NO. Toggles the Task sequence page.
- **SkipDomainMembership**: YES or NO. Toggles the Computer name section in the device details page.
- **SkipComputerName**: YES or NO. Toggles the Computer name section in the device details page.
- **DeploymentType**: ONLY SUPPORTS NEWDEPLOYMENT.
- **SkipAdminPassword**: YES or NO. Toggles the admin password section on the admin page.
- **SkipLocaleSelection**: YES or NO. Toggles the Language section on the locale page.
- **SkipTimeZone**: YES or NO. Toggles the Time Zone section on the locale page.
- **SkipApplications**: YES or NO. Toggles the Application page (see known issue).
- **SkipSummary**: YES or NO. Toggles the summary page (shows what was selected in the UI).

The main PSD variable definitions do not include the items listed below; they will need to be added to the Property section in the _CustomSettings.ini_:

- **PSDWizard**: Native or PSDWizardNew. Native is the original wizard (not new).
- **PSDWizardTheme**: Classic, Modern, Refresh, Tabular (see theme section for details and screenshots).
- **PSDWizardLogo**: Adds a logo to the top left corner of the wizard and the Welcome page (e.g., PSDWizardLogo=%SCRIPTROOT%\powershell.png).
- **SkipPSDWelcome**: YES or NO. Toggles the Welcome splash screen.
- **SkipDeployReadiness**: YES or NO. Toggles the deployment readiness page.
- **SkipReadinessCheck**: YES or NO. Skips any readiness checks. This option is ignored if SkipDeployReadiness is NO, and the readiness check will not run.
- **PSDReadinessAllowBypass**: YES or NO. Allows the PSD Wizard to continue even if the readiness check returns false.
- **PSDReadinessScript**: Place PowerShell script in %DEPLOYROOT%\PSDResources\Readiness folder.
- **PSDReadinessCheck001**: Invokes command or function from the readiness script.
- **PSDReadinessCheck002**: Invokes command or function from the readiness script.
- **PSDReadinessCheck003**: Invokes command or function from the readiness script.
- **PSDReadinessCheck004**: Invokes command or function from the readiness script.
- **PSDWizardCustomPaneAllowBypass**: YES or NO. If custom pages are added to the wizard and no script is provided, the next button will be disabled. This will override that.
- **PSDWizardCollapseTSList**: YES or NO. Collapses the Task Sequences folder list. By default, they are all expanded. This can be handy when there are a lot of folders.

> Review the _Readiness Additional requirements_ section for more details

- **PSDDebug**: YES or NO. Activates Debug Mode, and the constructed UI will be exported with logs.
![screenshot9](.images/image9.png)

## Readiness Additional requirements

The Deployment readiness page can be configured to run a readiness script against the device. The readiness checks have two requirements:

- It must be in PowerShell function form.
- It must return an object with two properties:
  - **Message**: 'Message to display' (keep the message short for UI display; recommended 60 characters or less).
  - **Ready**: True|False.

There can be as many functions as needed; however, only four can be invoked during the PSDWizard Deployment Readiness pane.

An example of a readiness function could look like:

```powershell
Function Test-IsUEFI{
    #create an object with two properties
    $Obj = "" | Select Ready,Message
    Try{
        $Null = Get-SecureBootUEFI -Name SetupMode -ErrorAction Stop
        $Obj.Message = "Running in UEFI Mode"
        $Obj.Ready = $True
    }Catch{
        $Obj.Message = "Not in UEFI Mode"
        $Obj.Ready = $False
    }
    Return $Obj
}
```

The output would look like this:
![screenshot9](.images/image10.png)

## Keyboard shortcuts

- **Escape** : will make the menu not be on top (allows other screens to go in front)
- **Space bar** : will close the PSD Welcome Wizard (if enabled)
- **Tab** : will navigate menu forward
- **Shift Tab** : will navigate menu reverse
- **F5**: will refresh Task sequence list
- **F9**: minimizes the wizard
- **Arrows**: Controls location of prestart menu if shows. Default to right

# Custom Pages

It is possible to add or remove pages in the PSD Wizard. Since a UDI wizard is not available yet, this process must be done manually and may require some experience with XAML.

> ATTENTION: there are sample pages here: https://github.com/PowerShellCrack/PSDWizardNew_CustomPages

## How to add a page

1. Open the definition file for a theme (eg. \<PSD>\Script\PSDWizardNew\Themes\Classic_Theme_Definitions_en-US.xml) in a Text editor

2. Add a new pane line with page details 

```xml
<Pane id="CustomPane_GroupPage" reference="Classic\PSDWizard_GroupPage_en-US.xaml" margin="0,0,0,0" />).
```
> NOTE: The list order DOES matter; it controls where the page will be

3. Add a new xaml file in the \<themes> folder and name it the same as the reference. In this example I would add a new file here:  <PSD>\Script\PSDWizardNew\Themes\Classic\PSDWizard_GroupPage_en-US.xaml.

![screenshot2](.images/image2.png)

4. Edit the page. It must consist of these elements (expect what's in bold). Be sure to give the name of the tab something unique (eg. x:Name="_grpTabLayout")

```xml
<Grid x:Name="_grpTabLayout" Margin="0" Grid.ColumnSpan="2">
    <Grid.ColumnDefinitions>
        <ColumnDefinition Width="490"></ColumnDefinition>
        <ColumnDefinition Width="150"></ColumnDefinition>
    </Grid.ColumnDefinitions>
    <Label x:Name="_grpTabMainTitle" Grid.Column="0" HorizontalAlignment="Left" Margin="10,20,0,0" VerticalAlignment="Top" FontSize="22" Content="@MainTitle"/>
    <Label x:Name="_grpTabSubTitle" FontSize="14" HorizontalAlignment="Left" Margin="10,73,0,0" VerticalAlignment="Top" Content="@SubTitle"/>

    <TextBox x:Name="TS_IntuneGroup" HorizontalAlignment="Left" Height="31" Margin="10,103,0,0" VerticalAlignment="Top" Width="331" Foreground='Gray' FontSize="18"/>

    <Label Content="More Info" Grid.Column="1" FontSize="14" HorizontalAlignment="Left" Margin="10,31,0,0" VerticalAlignment="Top" Foreground="LightSlateGray" />
    <TextBlock x:Name="_grpTabMoreInfo" Grid.Column="1" HorizontalAlignment="Left" Margin="10,89,0,0" Width="136" TextWrapping="Wrap" VerticalAlignment="Top" Height="422">
        <Run Text="@Help"/>
    </TextBlock>
</Grid>
```

![screenshot3](.images/image3.png)

5. Within the grid you can add code to make inputs, dropdowns, buttons, etc. The problem is, this code must be formatted correctly or the whole wizard won't load! I like to take code from other pages as an example. If you do this, any x:Name must be unique and by setting one of the x:Name with a TS_\<value>; will be exported as a variable when wizard is closed.

> HINT: Knowing the margins can be tricky; either use Visual Studio 2022 Community Edition to edit the xaml or copy code from another page of the same property. I copied the search input box from the application page and removed some properties. In this screenshot there is a section to build a two column page (help menu is in Column 1)
Follow these steps for a quick way to get your VS project setup: https://github.com/PowerShellCrack/PSDWizardNew_CustomPages/blob/main/Samples/README.MD

![screenshot4](.images/image4.png)

Here is what it looks like in VS2022

![screenshot5](.images/image5.png)

> The last thing to do is control how the page will display and what language. You'll notice in the VS2020 Screenshot, some text with @ in the. These are placeholders for words in a language. Even though English is the only supported language right now, this definition contains all types of pages and their conditions.

6. Open the main language definition file (eg. \<PSD>\Script\PSDWizardNew\PSDWizard_Definitions_en-US.xml) in a Text editor
Add a new Pane to where you want the pane to show up (order does matter here). The id must match the name designator of the page (eg. GroupPage is the designator for PSDWizard_GroupPage_en-US.xaml)

```xml
<Pane id="CustomPane_GroupPage" title="Intune Group">
    <Condition><![CDATA[ UCase(Property("SkipGroupPage")) <> "YES"]]></Condition>
    <MainTitle><![CDATA[ "Intune Group" ]]></MainTitle>
    <SubTitle><![CDATA[ "Group Name" ]]></SubTitle>
    <Help><![CDATA[ "Add an Azure AD group.&#xa;&#xa;These setting will be used during the deployment process.
    &#xa;&#xa;Add this device to an Intune group" ]]></Help>
</Pane>
```

![screenshot6](.images/image6.png)

> Optional: You can fill in the conditions, Main title, subtitle and help with what you want.
If done correctly you should get this:

7. Set the theme

![screenshot1](.images/image1.png)

8. Mount the ISO and boot the device and it should show up:

![screenshot7](.images\image7.png)

The ready page will also see the Task sequence variable. This will get exported when wizard complete for additional steps to take action

![screenshot8](.images/image8.png)

# CHANGELOG

The changelog can be found here: [CHANGELOG.MD](../Scripts/PSDWizardNew/CHANGELOG.md)

## BETA FEATURE

In addition to the new wizard, there is another module in beta:

- PSDStartLoader

The PSDStartLoader is a UI driven prestart menu (replaces the CLI prestart menu). This module can be activated within the bootstrap.ini

- **PSDPrestartMode** --> _Native_,_PrestartMenu_, or _FullScreen_. The Prestartmenu launches a menu within the boot sequence that provides other menus such as diskinfo, diskwipe, and static ip configuration. It can also detect if DART and CMtrace is installed in PE and will display a button for each

The _FullScreen_ option is still in BETA; it replaces the bginfo background with a UI backdrop (that will eventually monitor the TaskSequence in a modern fashion potentially replacing the task sequence progress bar). It to will present the prestart menu as well. _Native_ puts it back to CLI version.

> While the menu is loaded; you can use the keyboard's arrow keys to control the position of the menu. It defaults to the right side of screen. To preset the position, set the variable **PSDPrestartPosition** with one of these values: _VerticalLeft_, _VerticalRight_, _HorizontalTop_, _HorizontalBottom_

![menuonly](.images/prestartmenuloader_menuonly.png)

## Known issues

- Fixed in 2.2.7: Applications that have not ben toggled as disabled then reenabled, will not show in UI. Workaround is to use * in search.
- Fixed in 2.2.7: _SkipApplications=NO_ must exist in CustomSettings.ini if you want the application page to show
- Fixed in 2.2.9: OU was not populating in TS variable properly. Now provides multiple OU options like MDT did. 
- Fixed in 2.3.0: Custom pages can use scripts to populate pages for dynamic content
