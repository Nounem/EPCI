public with sharing class EpciSearchController {

    @AuraEnabled
    public static List<EpciGeoApiService.EpciWrapper> searchEpci(String nom) {
        if (String.isBlank(nom) || nom.trim().length() < 2) {
            return new List<EpciGeoApiService.EpciWrapper>();
        }
        return EpciGeoApiService.searchByNom(nom.trim());
    }

    @AuraEnabled
    public static EpciGeoApiService.EpciWrapper getEpciDetail(String code) {
        if (String.isBlank(code)) throw new AuraHandledException('Code EPCI requis');
        return EpciGeoApiService.getByCode(code);
    }

    @AuraEnabled
    public static List<EpciGeoApiService.CommuneWrapper> getCommunes(String code) {
        if (String.isBlank(code)) throw new AuraHandledException('Code EPCI requis');
        return EpciGeoApiService.getCommunesByCode(code);
    }

    @AuraEnabled
    public static EPCI__c saveEpci(
        String  nom,
        String  code,
        Decimal populationTotale,
        String  departements,
        Integer nombreCommunes,
        Decimal latitude,
        Decimal longitude,
        String  accountId
    ) {
        if (String.isBlank(code)) throw new AuraHandledException('Code EPCI requis');

        EPCI__c record = new EPCI__c(
            Name                   = nom,
            Code_EPCI__c           = code,
            Population_Totale__c   = populationTotale,
            Codes_Departements__c  = departements,
            Nombre_Communes__c     = nombreCommunes,
            Date_Enrichissement__c = Datetime.now(),
            Account__c             = String.isBlank(accountId) ? null : accountId
        );

        if (latitude != null && longitude != null) {
            record.Localisation__Latitude__s  = (Double) latitude;
            record.Localisation__Longitude__s = (Double) longitude;
        }

        upsert record Code_EPCI__c;
        return record;
    }

    @AuraEnabled
    public static void saveCommunes(String epciId, String communesJson) {
        if (String.isBlank(epciId) || String.isBlank(communesJson)) return;

        List<Object> raw = (List<Object>) JSON.deserializeUntyped(communesJson);
        List<Commune__c> toUpsert = new List<Commune__c>();

        for (Object item : raw) {
            Map<String, Object> m = (Map<String, Object>) item;
            toUpsert.add(new Commune__c(
                Name                = (String)  m.get('nom'),
                Code_INSEE__c       = (String)  m.get('code'),
                Code_Postal__c      = (String)  m.get('codePostal'),
                Population__c       = m.get('population') != null
                                        ? Integer.valueOf(m.get('population')) : null,
                Surface__c          = m.get('surface') != null
                                        ? Decimal.valueOf(String.valueOf(m.get('surface'))) : null,
                Code_Departement__c = (String)  m.get('codeDepartement'),
                Code_Region__c      = (String)  m.get('codeRegion'),
                EPCI__c             = epciId
            ));
        }

        upsert toUpsert Code_INSEE__c;
    }
}
