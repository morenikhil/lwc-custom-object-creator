import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createAllMetadata from '@salesforce/apex/CustomObjectCreatorController.createAllMetadata';

export default class CustomObjectCreator extends LightningElement {

    @track isLoading = false;
    @track logs = [];

    @track credentials = {
        loginUrl: 'https://test.salesforce.com',
        username: '',
        password: ''
    };

    @track objectConfig = {
        label: '',
        pluralLabel: '',
        apiName: '',
        nameFieldLabel: 'Name',
        nameFieldType: 'Text',
        sharingModel: 'ReadWrite',
        description: ''
    };

    @track fields = [];

    @track pageLayout = {
        create: true,
        name: '',
        includeAllFields: true
    };

    @track recordType = {
        create: false,
        apiName: '',
        label: '',
        description: ''
    };

    @track customTab = {
        create: true,
        motif: 'Custom39: Coins'
    };

    _fieldCounter = 0;
    _logCounter  = 0;

    // ── Static option lists ──────────────────────────────────────────────────

    get loginUrlOptions() {
        return [
            { label: 'Sandbox  (test.salesforce.com)',  value: 'https://test.salesforce.com'  },
            { label: 'Production  (login.salesforce.com)', value: 'https://login.salesforce.com' }
        ];
    }

    get nameFieldTypeOptions() {
        return [
            { label: 'Text',       value: 'Text'       },
            { label: 'AutoNumber', value: 'AutoNumber'  }
        ];
    }

    get sharingModelOptions() {
        return [
            { label: 'Read / Write',          value: 'ReadWrite'          },
            { label: 'Read',                  value: 'Read'               },
            { label: 'Private',               value: 'Private'            },
            { label: 'Controlled by Parent',  value: 'ControlledByParent' }
        ];
    }

    get fieldTypeOptions() {
        return [
            { label: 'Text',                    value: 'Text'                 },
            { label: 'Text Area',               value: 'TextArea'             },
            { label: 'Long Text Area',          value: 'LongTextArea'         },
            { label: 'Number',                  value: 'Number'               },
            { label: 'Currency',                value: 'Currency'             },
            { label: 'Percent',                 value: 'Percent'              },
            { label: 'Date',                    value: 'Date'                 },
            { label: 'Date / Time',             value: 'DateTime'             },
            { label: 'Checkbox',                value: 'Checkbox'             },
            { label: 'Email',                   value: 'Email'                },
            { label: 'Phone',                   value: 'Phone'                },
            { label: 'URL',                     value: 'Url'                  },
            { label: 'Picklist',                value: 'Picklist'             },
            { label: 'Multi-Select Picklist',   value: 'MultiselectPicklist'  }
        ];
    }

    get tabStyleOptions() {
        return [
            { label: 'Coins',       value: 'Custom39: Coins'      },
            { label: 'Star',        value: 'Custom18: Star'        },
            { label: 'Lightning',   value: 'Custom32: Lightning'   },
            { label: 'Globe',       value: 'Custom41: Globe'       },
            { label: 'Briefcase',   value: 'Custom44: Briefcase'   },
            { label: 'Airplane',    value: 'Custom54: Airplane'    },
            { label: 'Heart',       value: 'Custom60: Heart'       },
            { label: 'Phone',       value: 'Custom79: Phone'       },
            { label: 'Flower',      value: 'Custom89: Flower'      },
            { label: 'Sun',         value: 'Custom88: Sun'         }
        ];
    }

    get hasFields() { return this.fields.length > 0; }
    get hasLogs()   { return this.logs.length   > 0; }

    // ── Credentials ──────────────────────────────────────────────────────────

    handleCredentialChange(event) {
        const field = event.target.dataset.field;
        this.credentials = { ...this.credentials, [field]: event.target.value };
    }

    // ── Object config ─────────────────────────────────────────────────────────

    handleObjectChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.objectConfig = { ...this.objectConfig, [field]: value };
    }

    autoPopulateObjectFields() {
        const label = this.objectConfig.label;
        if (!label) return;

        if (!this.objectConfig.pluralLabel) {
            this.objectConfig = { ...this.objectConfig, pluralLabel: label + 's' };
        }
        if (!this.objectConfig.apiName) {
            const apiName = label.replace(/\s+/g, '_').replace(/[^a-zA-Z0-9_]/g, '');
            this.objectConfig = { ...this.objectConfig, apiName };
        }
        if (!this.pageLayout.name) {
            this.pageLayout = { ...this.pageLayout, name: label + ' Layout' };
        }
    }

    // ── Custom fields ─────────────────────────────────────────────────────────

    addField() {
        this._fieldCounter++;
        this.fields = [...this.fields, this._defaultField(this._fieldCounter)];
    }

    removeField(event) {
        const idx = parseInt(event.currentTarget.dataset.index, 10);
        this.fields = this.fields.filter((_, i) => i !== idx);
    }

    handleFieldChange(event) {
        const idx   = parseInt(event.target.dataset.index, 10);
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;

        this.fields = this.fields.map((f, i) => {
            if (i !== idx) return f;
            const updated = { ...f, [field]: value };
            if (field === 'dataType') Object.assign(updated, this._fieldTypeFlags(value));
            return updated;
        });
    }

    autoPopulateFieldApiName(event) {
        const idx   = parseInt(event.target.dataset.index, 10);
        const f     = this.fields[idx];
        if (!f || f.apiName || !f.label) return;
        const apiName = f.label.replace(/\s+/g, '_').replace(/[^a-zA-Z0-9_]/g, '');
        this.fields = this.fields.map((fld, i) => i === idx ? { ...fld, apiName } : fld);
    }

    _defaultField(id) {
        return {
            id,
            label: '',
            apiName: '',
            dataType: 'Text',
            length: 255,
            scale: 0,
            required: false,
            picklistValues: '',
            showLength: true,
            showLongLength: false,
            showDecimal: false,
            showPicklist: false
        };
    }

    _fieldTypeFlags(dataType) {
        return {
            showLength:     ['Text', 'TextArea'].includes(dataType),
            showLongLength: dataType === 'LongTextArea',
            showDecimal:    ['Number', 'Currency', 'Percent'].includes(dataType),
            showPicklist:   ['Picklist', 'MultiselectPicklist'].includes(dataType)
        };
    }

    // ── Page layout ───────────────────────────────────────────────────────────

    handlePageLayoutToggle(event) {
        this.pageLayout = { ...this.pageLayout, create: event.target.checked };
    }

    handlePageLayoutChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.pageLayout = { ...this.pageLayout, [field]: value };
    }

    // ── Record type ───────────────────────────────────────────────────────────

    handleRecordTypeToggle(event) {
        this.recordType = { ...this.recordType, create: event.target.checked };
    }

    handleRecordTypeChange(event) {
        const field = event.target.dataset.field;
        this.recordType = { ...this.recordType, [field]: event.target.value };
    }

    // ── Custom tab ────────────────────────────────────────────────────────────

    handleTabToggle(event) {
        this.customTab = { ...this.customTab, create: event.target.checked };
    }

    handleTabChange(event) {
        const field = event.target.dataset.field;
        this.customTab = { ...this.customTab, [field]: event.target.value };
    }

    // ── Reset ─────────────────────────────────────────────────────────────────

    handleReset() {
        this.credentials  = { loginUrl: 'https://test.salesforce.com', username: '', password: '' };
        this.objectConfig = { label: '', pluralLabel: '', apiName: '', nameFieldLabel: 'Name', nameFieldType: 'Text', sharingModel: 'ReadWrite', description: '' };
        this.fields       = [];
        this.pageLayout   = { create: true,  name: '', includeAllFields: true  };
        this.recordType   = { create: false, apiName: '', label: '', description: '' };
        this.customTab    = { create: true,  motif: 'Custom39: Coins' };
        this.logs         = [];
        this._fieldCounter = 0;
    }

    // ── Create ────────────────────────────────────────────────────────────────

    async handleCreate() {
        if (!this._validateForm()) return;

        this.isLoading = true;
        this.logs      = [];
        this._addLog('info', 'Starting — authenticating to ' + this.credentials.loginUrl + ' ...');

        // Ensure __c suffix on object API name
        let apiName = this.objectConfig.apiName;
        if (!apiName.endsWith('__c')) {
            apiName = apiName + '__c';
            this.objectConfig = { ...this.objectConfig, apiName };
        }

        try {
            const result = await createAllMetadata({
                credentialsJson:  JSON.stringify(this.credentials),
                objectConfigJson: JSON.stringify(this.objectConfig),
                fieldsJson:       JSON.stringify(this.fields),
                pageLayoutJson:   JSON.stringify(this.pageLayout),
                recordTypeJson:   JSON.stringify(this.recordType),
                customTabJson:    JSON.stringify(this.customTab)
            });

            const steps = JSON.parse(result);
            steps.forEach(s => this._addLog(s.success ? 'success' : 'error', s.message));

            const anyError = steps.some(s => !s.success);
            this._toast(
                anyError ? 'Completed with Warnings' : 'All Done!',
                anyError ? 'Some steps had errors — see the log below.' : 'All metadata created successfully in target org.',
                anyError ? 'warning' : 'success'
            );
        } catch (err) {
            const msg = (err.body && err.body.message) ? err.body.message : (err.message || 'Unknown error');
            this._addLog('error', 'Apex error: ' + msg);
            this._toast('Error', msg, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ── Validation ────────────────────────────────────────────────────────────

    _validateForm() {
        const allInputs = [
            ...this.template.querySelectorAll('lightning-input'),
            ...this.template.querySelectorAll('lightning-combobox'),
            ...this.template.querySelectorAll('lightning-textarea')
        ];
        const inputsValid = allInputs.reduce((acc, el) => el.reportValidity() && acc, true);

        if (!this.credentials.username || !this.credentials.password) {
            this._toast('Validation Error', 'Username and password are required.', 'error');
            return false;
        }
        if (!this.objectConfig.label || !this.objectConfig.apiName) {
            this._toast('Validation Error', 'Object Label and API Name are required.', 'error');
            return false;
        }
        if (this.pageLayout.create && !this.pageLayout.name) {
            this._toast('Validation Error', 'Layout Name is required when creating a Page Layout.', 'error');
            return false;
        }
        if (this.recordType.create && (!this.recordType.apiName || !this.recordType.label)) {
            this._toast('Validation Error', 'Record Type API Name and Label are required.', 'error');
            return false;
        }
        return inputsValid;
    }

    // ── Log helpers ───────────────────────────────────────────────────────────

    _addLog(type, message) {
        this._logCounter++;
        const iconMap = { info: 'utility:info', success: 'utility:success', error: 'utility:error', warning: 'utility:warning' };
        const cssMap  = { info: 'log-entry log-info', success: 'log-entry log-success', error: 'log-entry log-error', warning: 'log-entry log-warning' };
        this.logs = [...this.logs, {
            id:        this._logCounter,
            type,
            message,
            timestamp: new Date().toLocaleTimeString(),
            icon:      iconMap[type]  || 'utility:info',
            cssClass:  cssMap[type]   || 'log-entry log-info'
        }];
    }

    clearLogs() { this.logs = []; }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
