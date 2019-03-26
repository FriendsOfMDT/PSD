# Operators Guide - PowerShell Deployment Extension Kit
April 2019

## Introduction

## Installation

## Configuration

## Automating PSD

## New Variables
The following new TS variables are provided with PSD. Any new   or additional Task Sequence variables  **must** be instatiated and called via Bootstrap.ini or CustomSettings.ini !! Do NOT edit ZTIGather.xml.

- IsOnBattery
- IsVM
- IsSFF
- IsTablet
- Devxxxx
- DevXXXXX

### Bootstrap.ini

### CustomSettings.ini

## Your first PSD Task Sequence
Make sure your target device meets the minimum hardware specifications:
- 1.5GB RAM or better (WinPE has been extended and requires additional memory)
- Network adapter(s)
- At least 50GB hard drive (for New/BareMetal deployments)
- At least XXX MHz processor (for New/BareMetal deployments)