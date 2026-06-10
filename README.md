# LWC Custom Object Creator

A Salesforce Lightning Web Component (LWC) that lets you create a fully configured custom object — including custom fields, page layout, record type, and custom tab — in **any sandbox or production org** from a single screen.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Installation & Deployment](#installation--deployment)
- [Remote Site Settings Setup](#remote-site-settings-setup)
- [How to Use](#how-to-use)
- [Supported Field Data Types](#supported-field-data-types)
- [Architecture](#architecture)
- [Troubleshooting](#troubleshooting)

---

## Overview

Instead of manually navigating through Salesforce Setup to create objects, fields, layouts, and tabs one by one, this tool provides a **single-screen form** where you fill in all the details and click **Create** — everything gets provisioned automatically in the target org via the Salesforce Metadata API.

![Component Screenshot](https://placehold.co/900x500?text=Custom+Object+Creator+LWC)

---

## Features

| Feature | Description |
|---------|-------------|
| **Cross-Org Support** | Enter credentials for any sandbox or production org |
| **Custom Object** | Set label, plural label, API name, name field type, sharing model |
| **Multiple Custom Fields** | Add unlimited fields dynamically with data type selection |
| **Page Layout** | Auto-generates a layout and optionally includes all custom fields |
| **Record Type** | Create a record type with label, API name, and description |
| **Custom Tab** | Creates a tab with your choice of icon/style |
| **Creation Log** | Real-time step-by-step log panel shows success or error for each item |
| **Form Validation** | Client-side validation before any API call is made |

---

## Project Structure

```
lwc-custom-object-creator/
├── sfdx-project.json
├── README.md
└── force-app/
    └── main/
        └── default/
            ├── lwc/
            │   └── customObjectCreator/
            │       ├── customObjectCreator.html          # UI — 6-step form
            │       ├── customObjectCreator.js            # Component logic
            │       ├── customObjectCreator.css           # Styling
            │       └── customObjectCreator.js-meta.xml   # Metadata config
            ├── classes/
            │   ├── CustomObjectCreatorController.cls          # Apex backend
            │   └── CustomObjectCreatorController.cls-meta.xml
            └── remoteSiteSettings/
                ├── SF_Login.remoteSite-meta.xml   # login.salesforce.com
                └── SF_Test.remoteSite-meta.xml    # test.salesforce.com
```

---

## Prerequisites

Before deploying, make sure you have the following installed:

### 1. Salesforce CLI
```bash
# Check if already installed
sf --version

# If not installed, download from:
# https://developer.salesforce.com/tools/salesforcecli
```

### 2. Git
```bash
git --version
```

### 3. A Salesforce org (Developer / Sandbox) to deploy the component into

---

## Installation & Deployment

### Step 1 — Clone the repository
```bash
git clone https://github.com/morenikhil/lwc-custom-object-creator.git
cd lwc-custom-object-creator
```

### Step 2 — Authenticate to your org
```bash
# For a Sandbox
sf org login web --alias myOrg --instance-url https://test.salesforce.com

# For a Developer / Production org
sf org login web --alias myOrg --instance-url https://login.salesforce.com
```

### Step 3 — Deploy the project
```bash
sf project deploy start --source-dir force-app --target-org myOrg
```

### Step 4 — Open the org and verify
```bash
sf org open --target-org myOrg
```

---

## Remote Site Settings Setup

> **This step is required** before the component can make API callouts.

The Apex controller calls external Salesforce endpoints. The **login URLs** are included automatically via the deployed Remote Site Settings. However, you must **manually add the target org's instance URL**.

### What is already included (auto-deployed):
| Remote Site | URL |
|-------------|-----|
| SF_Login | `https://login.salesforce.com` |
| SF_Test  | `https://test.salesforce.com`  |

### What you need to add manually:

1. Go to **Setup** → search **Remote Site Settings** → click **New**
2. Enter a name, e.g. `MyTargetOrg`
3. Enter the **instance URL** of the org you want to create objects in  
   *(e.g. `https://na1.salesforce.com` or `https://mycompany.sandbox.my.salesforce.com`)*
4. Click **Save**

> **Tip:** You can find your org's instance URL by logging into it and checking the browser address bar.

---

## How to Use

Once deployed, open the component from the **App Launcher** or add it to a Lightning App Page.

### Step-by-Step Guide

#### Step 1 — Enter Target Org Credentials
| Field | Description |
|-------|-------------|
| Login URL | Select Sandbox or Production |
| Username | Your login email for the target org |
| Password + Security Token | Concatenate password and security token (e.g. `MyPassword123TokenXYZ`) |

> **Where to find your Security Token:**  
> Target org → Profile Icon → Settings → Reset My Security Token

---

#### Step 2 — Custom Object Details
| Field | Description |
|-------|-------------|
| Object Label | Human-readable name (e.g. `Work Order`) |
| Plural Label | Plural form (e.g. `Work Orders`) — auto-filled |
| API Name | Developer name without `__c` (e.g. `Work_Order`) — auto-filled |
| Name Field Label | Label for the standard Name field |
| Name Field Type | `Text` or `AutoNumber` |
| Sharing Model | `Read/Write`, `Read`, `Private`, or `Controlled by Parent` |
| Description | Optional description for the object |

---

#### Step 3 — Custom Fields
Click **+ Add Field** to add as many fields as needed.

| Column | Description |
|--------|-------------|
| Field Label | Display name |
| API Name | Developer name without `__c` — auto-filled from label |
| Data Type | Select from 14 supported types (see below) |
| Length / Decimal / Values | Shown conditionally based on the selected data type |
| Required | Check to make the field mandatory |

Click the **red delete icon** to remove a field row.

---

#### Step 4 — Page Layout
- Toggle **ON** to create a Page Layout
- Enter a **Layout Name** (e.g. `Work Order Layout`)
- Check **Auto-include all custom fields** to automatically add every field you created into the layout

---

#### Step 5 — Record Type
- Toggle **ON** to create a Record Type
- Enter **API Name**, **Label**, and an optional **Description**

---

#### Step 6 — Custom Tab
- Toggle **ON** to create a Custom Tab
- Choose an **icon style** from the dropdown

---

#### Click "Create"
The component will:
1. Authenticate to the target org
2. Create the custom object
3. Create each field one by one
4. Create the page layout
5. Create the record type (if enabled)
6. Create the custom tab (if enabled)

A **real-time log** at the bottom shows the result of each step with a green (success) or red (error) indicator.

---

## Supported Field Data Types

| Data Type | Extra Config |
|-----------|-------------|
| Text | Max Length (1–255) |
| Text Area | Max Length (1–255) |
| Long Text Area | Max Length (256–131072) |
| Number | Decimal Places |
| Currency | Decimal Places |
| Percent | Decimal Places |
| Date | — |
| Date / Time | — |
| Checkbox | — |
| Email | — |
| Phone | — |
| URL | — |
| Picklist | Values (one per line) |
| Multi-Select Picklist | Values (one per line) |

---

## Architecture

```
Browser (LWC)
     │
     │  @AuraEnabled Apex call (JSON payloads)
     ▼
CustomObjectCreatorController.cls
     │
     ├─ 1. SOAP Login API  →  login.salesforce.com / test.salesforce.com
     │       Returns: sessionId + metadataServerUrl
     │
     └─ 2. Metadata API SOAP  →  <instance>.salesforce.com/services/Soap/m/59.0
             create(CustomObject)
             create(CustomField)   ← repeated per field
             create(Layout)
             create(RecordType)
             create(CustomTab)
```

### Key Files

| File | Role |
|------|------|
| `customObjectCreator.html` | 6-section form UI using SLDS components |
| `customObjectCreator.js` | State management, validation, Apex callout |
| `customObjectCreator.css` | Section styling + dark terminal-style log panel |
| `CustomObjectCreatorController.cls` | Auth via SOAP Partner API, all Metadata API SOAP calls |

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `Authentication failed` | Check username/password + security token. Make sure login URL matches org type (sandbox vs production). |
| `Callout error` / `endpoint not allowed` | Add the target org's instance URL to Remote Site Settings (see [Remote Site Settings Setup](#remote-site-settings-setup)). |
| `DUPLICATE_DEVELOPER_NAME` | An object/field with that API name already exists in the target org. Use a different name. |
| `INVALID_TYPE` error on field | The selected data type may have a missing required attribute. Check Length or Decimal settings. |
| Layout creation fails | Verify the object was created successfully first. Layout depends on the object existing. |
| Blank log after clicking Create | Check browser console for errors. Ensure the Apex class is deployed and the user has `Modify All Data` permission. |

---

## License

This project is open-source.

---

## Author

**Nikhil More**  
GitHub: [@morenikhil](https://github.com/morenikhil)
