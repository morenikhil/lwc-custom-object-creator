/**
 * Backend for the customObjectCreator LWC.
 * Authenticates to a target Salesforce org via SOAP Partner API login,
 * then uses the Metadata API SOAP to create:
 *   CustomObject → CustomField(s) → Layout → RecordType → CustomTab
 *
 * Prerequisites (Remote Site Settings required in THIS org):
 *   https://login.salesforce.com
 *   https://test.salesforce.com
 *   https://<target-instance>.salesforce.com   (e.g. na1, cs42, etc.)
 */
public with sharing class CustomObjectCreatorController {

    // ── Entry point ───────────────────────────────────────────────────────────

    @AuraEnabled
    public static String createAllMetadata(
        String credentialsJson,
        String objectConfigJson,
        String fieldsJson,
        String pageLayoutJson,
        String recordTypeJson,
        String customTabJson
    ) {
        List<StepResult> results = new List<StepResult>();

        Map<String, Object> creds      = (Map<String, Object>) JSON.deserializeUntyped(credentialsJson);
        Map<String, Object> objCfg     = (Map<String, Object>) JSON.deserializeUntyped(objectConfigJson);
        List<Object>        fieldList  = (List<Object>)        JSON.deserializeUntyped(fieldsJson);
        Map<String, Object> layoutCfg  = (Map<String, Object>) JSON.deserializeUntyped(pageLayoutJson);
        Map<String, Object> rtCfg      = (Map<String, Object>) JSON.deserializeUntyped(recordTypeJson);
        Map<String, Object> tabCfg     = (Map<String, Object>) JSON.deserializeUntyped(customTabJson);

        // ── Step 1: Authenticate ──────────────────────────────────────────────
        String username  = (String) creds.get('username');
        String password  = (String) creds.get('password');
        String loginUrl  = (String) creds.get('loginUrl');

        AuthResult auth = authenticate(username, password, loginUrl);
        if (!auth.success) {
            results.add(new StepResult(false, 'Authentication failed: ' + auth.errorMessage));
            return JSON.serialize(results);
        }
        results.add(new StepResult(true, 'Authenticated successfully to ' + auth.instanceUrl));

        String sessionId    = auth.sessionId;
        String metadataUrl  = auth.metadataServerUrl;

        // Ensure __c suffix
        String objApiName = (String) objCfg.get('apiName');
        if (!objApiName.endsWith('__c')) objApiName += '__c';

        // ── Step 2: Custom Object ─────────────────────────────────────────────
        StepResult objResult = createCustomObject(sessionId, metadataUrl, objCfg, objApiName);
        results.add(objResult);
        if (!objResult.success) return JSON.serialize(results); // Can't proceed without the object

        // ── Step 3: Custom Fields ─────────────────────────────────────────────
        for (Object rawField : fieldList) {
            Map<String, Object> fld = (Map<String, Object>) rawField;
            results.add(createCustomField(sessionId, metadataUrl, fld, objApiName));
        }

        // ── Step 4: Page Layout ───────────────────────────────────────────────
        if ((Boolean) layoutCfg.get('create')) {
            results.add(createPageLayout(sessionId, metadataUrl, layoutCfg, objApiName, fieldList));
        }

        // ── Step 5: Record Type ───────────────────────────────────────────────
        if ((Boolean) rtCfg.get('create')) {
            results.add(createRecordType(sessionId, metadataUrl, rtCfg, objApiName));
        }

        // ── Step 6: Custom Tab ────────────────────────────────────────────────
        if ((Boolean) tabCfg.get('create')) {
            results.add(createCustomTab(sessionId, metadataUrl, tabCfg, objApiName));
        }

        return JSON.serialize(results);
    }

    // ── Authentication (SOAP Partner API) ────────────────────────────────────

    private static AuthResult authenticate(String username, String password, String loginUrl) {
        String soapBody =
            '<?xml version="1.0" encoding="UTF-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
                              'xmlns:urn="urn:partner.soap.sforce.com">' +
              '<soapenv:Body>' +
                '<urn:login>' +
                  '<urn:username>' + escXml(username) + '</urn:username>' +
                  '<urn:password>' + escXml(password) + '</urn:password>' +
                '</urn:login>' +
              '</soapenv:Body>' +
            '</soapenv:Envelope>';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(loginUrl + '/services/Soap/u/59.0');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'text/xml; charset=UTF-8');
        req.setHeader('SOAPAction', 'login');
        req.setTimeout(30000);
        req.setBody(soapBody);

        HttpResponse res = new Http().send(req);
        String body = res.getBody();

        AuthResult result = new AuthResult();

        if (res.getStatusCode() != 200) {
            result.success      = false;
            String faultMsg = extractXml(body, 'faultstring');
            result.errorMessage = faultMsg != null ? faultMsg : ('HTTP ' + res.getStatusCode());
            return result;
        }

        result.success           = true;
        result.sessionId         = extractXml(body, 'sessionId');
        result.metadataServerUrl = extractXml(body, 'metadataServerUrl');

        // Extract base instance URL from serverUrl  e.g. https://na1.salesforce.com/services/...
        String serverUrl = extractXml(body, 'serverUrl');
        if (serverUrl != null) {
            Integer slashIdx = serverUrl.indexOf('/', 8); // skip 'https://'
            result.instanceUrl = slashIdx > 0 ? serverUrl.substring(0, slashIdx) : serverUrl;
        }
        return result;
    }

    // ── Create Custom Object ──────────────────────────────────────────────────

    private static StepResult createCustomObject(String sessionId, String metadataUrl,
                                                  Map<String, Object> cfg, String apiName) {
        String label          = strVal(cfg, 'label');
        String pluralLabel    = strVal(cfg, 'pluralLabel');
        String nameFieldLabel = strVal(cfg, 'nameFieldLabel');
        String nameFieldType  = strVal(cfg, 'nameFieldType');
        String sharingModel   = strVal(cfg, 'sharingModel');
        String description    = strVal(cfg, 'description');

        String xml =
            '<met:metadata xsi:type="met:CustomObject">' +
              '<met:fullName>'    + escXml(apiName)      + '</met:fullName>'    +
              '<met:label>'       + escXml(label)         + '</met:label>'       +
              '<met:pluralLabel>' + escXml(pluralLabel)   + '</met:pluralLabel>' +
              '<met:nameField>'   +
                '<met:label>' + escXml(String.isBlank(nameFieldLabel) ? 'Name' : nameFieldLabel) + '</met:label>' +
                '<met:type>'  + escXml(String.isBlank(nameFieldType)  ? 'Text' : nameFieldType)  + '</met:type>'  +
              '</met:nameField>'  +
              '<met:deploymentStatus>Deployed</met:deploymentStatus>' +
              '<met:sharingModel>' + escXml(String.isBlank(sharingModel) ? 'ReadWrite' : sharingModel) + '</met:sharingModel>' +
              (String.isNotBlank(description) ? '<met:description>' + escXml(description) + '</met:description>' : '') +
            '</met:metadata>';

        String resp = callMetadata(sessionId, metadataUrl, 'create', xml);
        return parseResponse(resp, 'Create Object: ' + apiName);
    }

    // ── Create Custom Field ───────────────────────────────────────────────────

    private static StepResult createCustomField(String sessionId, String metadataUrl,
                                                 Map<String, Object> fld, String objApiName) {
        String fieldLabel = strVal(fld, 'label');
        String fieldApi   = strVal(fld, 'apiName');
        if (!fieldApi.endsWith('__c')) fieldApi += '__c';

        String dataType  = strVal(fld, 'dataType');
        Boolean required = boolVal(fld, 'required');
        Integer length   = intVal(fld, 'length',  255);
        Integer scale    = intVal(fld, 'scale',   0);
        String  plValues = strVal(fld, 'picklistValues');

        String fullName = objApiName + '.' + fieldApi;

        String xml =
            '<met:metadata xsi:type="met:CustomField">' +
              '<met:fullName>' + escXml(fullName)    + '</met:fullName>' +
              '<met:label>'    + escXml(fieldLabel)   + '</met:label>'    +
              '<met:type>'     + escXml(dataType)     + '</met:type>';

        if (dataType == 'Text' || dataType == 'TextArea') {
            xml += '<met:length>' + length + '</met:length>';
        } else if (dataType == 'LongTextArea') {
            xml += '<met:length>' + (length < 256 ? 32768 : length) + '</met:length>' +
                   '<met:visibleLines>5</met:visibleLines>';
        } else if (dataType == 'Number' || dataType == 'Currency' || dataType == 'Percent') {
            xml += '<met:precision>18</met:precision><met:scale>' + scale + '</met:scale>';
        } else if (dataType == 'Picklist' || dataType == 'MultiselectPicklist') {
            xml += buildPicklistXml(plValues);
            if (dataType == 'MultiselectPicklist') xml += '<met:visibleLines>4</met:visibleLines>';
        }

        if (required) xml += '<met:required>true</met:required>';
        xml += '</met:metadata>';

        String resp = callMetadata(sessionId, metadataUrl, 'create', xml);
        return parseResponse(resp, 'Create Field: ' + fullName);
    }

    // ── Create Page Layout ────────────────────────────────────────────────────

    private static StepResult createPageLayout(String sessionId, String metadataUrl,
                                                Map<String, Object> layoutCfg, String objApiName,
                                                List<Object> fields) {
        String layoutName     = strVal(layoutCfg, 'name');
        Boolean includeFields = boolVal(layoutCfg, 'includeAllFields');
        String fullName       = objApiName + '-' + layoutName;

        // Build layout items — always include Name first
        String items = '<met:layoutItems><met:behavior>Required</met:behavior><met:field>Name</met:field></met:layoutItems>';

        if (includeFields && fields != null) {
            for (Object rawF : fields) {
                Map<String, Object> f = (Map<String, Object>) rawF;
                String fApi = strVal(f, 'apiName');
                if (!fApi.endsWith('__c')) fApi += '__c';
                String dtype = strVal(f, 'dataType');
                String behavior = (dtype == 'Checkbox') ? 'Edit' : 'Edit';
                items +=
                    '<met:layoutItems>' +
                      '<met:behavior>' + behavior + '</met:behavior>' +
                      '<met:field>' + escXml(fApi) + '</met:field>' +
                    '</met:layoutItems>';
            }
        }

        String xml =
            '<met:metadata xsi:type="met:Layout">' +
              '<met:fullName>' + escXml(fullName) + '</met:fullName>' +
              '<met:layoutSections>' +
                '<met:customLabel>false</met:customLabel>' +
                '<met:detailHeading>true</met:detailHeading>' +
                '<met:editHeading>true</met:editHeading>' +
                '<met:label>Information</met:label>' +
                '<met:layoutColumns>' + items + '</met:layoutColumns>' +
                '<met:layoutColumns/>' +
                '<met:style>TwoColumnsTopToBottom</met:style>' +
              '</met:layoutSections>' +
            '</met:metadata>';

        String resp = callMetadata(sessionId, metadataUrl, 'create', xml);
        return parseResponse(resp, 'Create Layout: ' + fullName);
    }

    // ── Create Record Type ────────────────────────────────────────────────────

    private static StepResult createRecordType(String sessionId, String metadataUrl,
                                                Map<String, Object> rtCfg, String objApiName) {
        String rtApi   = strVal(rtCfg, 'apiName');
        String rtLabel = strVal(rtCfg, 'label');
        String rtDesc  = strVal(rtCfg, 'description');
        String fullName = objApiName + '.' + rtApi;

        String xml =
            '<met:metadata xsi:type="met:RecordType">' +
              '<met:fullName>' + escXml(fullName) + '</met:fullName>' +
              '<met:label>'    + escXml(rtLabel)  + '</met:label>'    +
              '<met:active>true</met:active>' +
              (String.isNotBlank(rtDesc) ? '<met:description>' + escXml(rtDesc) + '</met:description>' : '') +
            '</met:metadata>';

        String resp = callMetadata(sessionId, metadataUrl, 'create', xml);
        return parseResponse(resp, 'Create Record Type: ' + fullName);
    }

    // ── Create Custom Tab ─────────────────────────────────────────────────────

    private static StepResult createCustomTab(String sessionId, String metadataUrl,
                                               Map<String, Object> tabCfg, String objApiName) {
        String motif = strVal(tabCfg, 'motif');
        if (String.isBlank(motif)) motif = 'Custom39: Coins';

        String xml =
            '<met:metadata xsi:type="met:CustomTab">' +
              '<met:fullName>'      + escXml(objApiName) + '</met:fullName>' +
              '<met:customObject>true</met:customObject>' +
              '<met:motif>'         + escXml(motif)      + '</met:motif>'    +
            '</met:metadata>';

        String resp = callMetadata(sessionId, metadataUrl, 'create', xml);
        return parseResponse(resp, 'Create Custom Tab for: ' + objApiName);
    }

    // ── SOAP Metadata API callout ─────────────────────────────────────────────

    private static String callMetadata(String sessionId, String metadataUrl,
                                        String operation, String metadataXml) {
        String envelope =
            '<?xml version="1.0" encoding="UTF-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
                              'xmlns:met="http://soap.sforce.com/2006/04/metadata" ' +
                              'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">' +
              '<soapenv:Header>' +
                '<met:CallOptions><met:client>CustomObjectCreator/1.0</met:client></met:CallOptions>' +
                '<met:SessionHeader><met:sessionId>' + escXml(sessionId) + '</met:sessionId></met:SessionHeader>' +
              '</soapenv:Header>' +
              '<soapenv:Body>' +
                '<met:' + operation + '>' + metadataXml + '</met:' + operation + '>' +
              '</soapenv:Body>' +
            '</soapenv:Envelope>';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(metadataUrl);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'text/xml; charset=UTF-8');
        req.setHeader('SOAPAction', '""');
        req.setTimeout(120000);
        req.setBody(envelope);

        HttpResponse res = new Http().send(req);
        return res.getBody();
    }

    // ── Response parser ───────────────────────────────────────────────────────

    private static StepResult parseResponse(String body, String operationLabel) {
        if (body == null) return new StepResult(false, operationLabel + ' — null response');

        if (body.contains('<success>true</success>')) {
            String fullName = extractXml(body, 'fullName');
            return new StepResult(true, operationLabel + (fullName != null ? ' [' + fullName + ']' : '') + ' — Success');
        }

        // Try to pull a useful error message
        String errMsg = extractXml(body, 'message');
        if (errMsg == null) errMsg = extractXml(body, 'faultstring');
        if (errMsg == null) errMsg = 'Unknown error. Check setup.';

        String statusCode = extractXml(body, 'statusCode');
        String detail = (statusCode != null ? '[' + statusCode + '] ' : '') + errMsg;
        return new StepResult(false, operationLabel + ' — Error: ' + detail);
    }

    // ── Picklist XML builder ──────────────────────────────────────────────────

    private static String buildPicklistXml(String rawValues) {
        List<String> valueLines = new List<String>();
        if (String.isNotBlank(rawValues)) {
            for (String v : rawValues.split('\n')) {
                v = v.trim();
                if (String.isNotBlank(v)) valueLines.add(v);
            }
        }
        if (valueLines.isEmpty()) valueLines.add('Option 1');

        String xml = '<met:valueSet><met:valueSetDefinition><met:sorted>false</met:sorted>';
        Boolean first = true;
        for (String v : valueLines) {
            String fn = v.replaceAll('[^a-zA-Z0-9_]', '_');
            xml +=
                '<met:value>' +
                  '<met:fullName>' + escXml(fn) + '</met:fullName>' +
                  '<met:default>'  + (first ? 'true' : 'false') + '</met:default>' +
                  '<met:label>'    + escXml(v)  + '</met:label>'  +
                '</met:value>';
            first = false;
        }
        xml += '</met:valueSetDefinition></met:valueSet>';
        return xml;
    }

    // ── XML helpers ───────────────────────────────────────────────────────────

    private static String extractXml(String xml, String tag) {
        if (xml == null || tag == null) return null;
        String open  = '<'  + tag + '>';
        String close = '</' + tag + '>';
        Integer s = xml.indexOf(open);
        if (s == -1) return null;
        s += open.length();
        Integer e = xml.indexOf(close, s);
        return e == -1 ? null : xml.substring(s, e);
    }

    private static String escXml(String s) {
        if (s == null) return '';
        return s.replace('&', '&amp;')
                .replace('<', '&lt;')
                .replace('>', '&gt;')
                .replace('"', '&quot;')
                .replace('\'', '&apos;');
    }

    // ── Typed field accessors ─────────────────────────────────────────────────

    private static String strVal(Map<String, Object> m, String key) {
        Object v = m.get(key);
        return v instanceof String ? (String) v : (v != null ? String.valueOf(v) : '');
    }

    private static Boolean boolVal(Map<String, Object> m, String key) {
        Object v = m.get(key);
        if (v instanceof Boolean) return (Boolean) v;
        if (v instanceof String)  return ((String) v).equalsIgnoreCase('true');
        return false;
    }

    private static Integer intVal(Map<String, Object> m, String key, Integer defaultVal) {
        Object v = m.get(key);
        if (v == null) return defaultVal;
        try { return Integer.valueOf(String.valueOf(v)); } catch (Exception e) { return defaultVal; }
    }

    // ── Inner classes ─────────────────────────────────────────────────────────

    private class AuthResult {
        Boolean success          = false;
        String  sessionId;
        String  metadataServerUrl;
        String  instanceUrl;
        String  errorMessage;
    }

    private class StepResult {
        Boolean success;
        String  message;
        StepResult(Boolean s, String m) { success = s; message = m; }
    }
}
