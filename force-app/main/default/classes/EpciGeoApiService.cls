public with sharing class EpciGeoApiService {

    private static final String  BASE_URL      = 'https://geo.api.gouv.fr/epcis';
    private static final Integer COMMUNE_LIMIT = 500;

    private static final String SEARCH_FIELDS =
        'nom,code,populationTotale,codesDepartements,codesCommunes';

    private static final String DETAIL_FIELDS =
        'nom,code,populationTotale,codesDepartements,codesCommunes,centre';

    private static final String COMMUNE_FIELDS =
        'nom,code,codesPostaux,population,surface,codeDepartement,codeRegion';

    public static List<EpciWrapper> searchByNom(String nom) {
        if (String.isBlank(nom)) {
            return new List<EpciWrapper>();
        }
        String url = BASE_URL
            + '?nom='    + EncodingUtil.urlEncode(nom, 'UTF-8')
            + '&fields=' + SEARCH_FIELDS
            + '&limit=10';
        List<EpciWrapper> result = new List<EpciWrapper>();
        for (Object item : (List<Object>) JSON.deserializeUntyped(doGet(url))) {
            result.add(mapToWrapper((Map<String, Object>) item));
        }
        return result;
    }

    public static EpciWrapper getByCode(String code) {
        if (String.isBlank(code)) {
            throw new EpciApiException('Code EPCI requis');
        }
        String url = BASE_URL
            + '/' + EncodingUtil.urlEncode(code, 'UTF-8')
            + '?fields=' + DETAIL_FIELDS;
        return mapToWrapper((Map<String, Object>) JSON.deserializeUntyped(doGet(url)));
    }

    public static List<CommuneWrapper> getCommunesByCode(String code) {
        if (String.isBlank(code)) {
            throw new EpciApiException('Code EPCI requis');
        }
        String url = BASE_URL
            + '/' + EncodingUtil.urlEncode(code, 'UTF-8')
            + '/communes?fields=' + COMMUNE_FIELDS
            + '&limit=' + COMMUNE_LIMIT;
        List<CommuneWrapper> result = new List<CommuneWrapper>();
        for (Object item : (List<Object>) JSON.deserializeUntyped(doGet(url))) {
            result.add(mapToCommune((Map<String, Object>) item));
        }
        return result;
    }

    private static String doGet(String url) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('GET');
        req.setTimeout(10000);
        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new EpciApiException(
                'Erreur API geo.api.gouv.fr — HTTP ' + res.getStatusCode()
            );
        }
        return res.getBody();
    }

    private static EpciWrapper mapToWrapper(Map<String, Object> m) {
        EpciWrapper w = new EpciWrapper();
        w.code             = (String) m.get('code');
        w.nom              = (String) m.get('nom');
        w.populationTotale = m.get('populationTotale') != null
            ? Integer.valueOf(m.get('populationTotale')) : null;

        List<Object> deps = (List<Object>) m.get('codesDepartements');
        if (deps != null) {
            List<String> dl = new List<String>();
            for (Object d : deps) dl.add((String) d);
            w.departements = String.join(dl, ', ');
        }

        List<Object> codesCommunes = (List<Object>) m.get('codesCommunes');
        if (codesCommunes != null) {
            w.nombreCommunes = codesCommunes.size();
        }

        Map<String, Object> centre = (Map<String, Object>) m.get('centre');
        if (centre != null) {
            List<Object> coords = (List<Object>) centre.get('coordinates');
            if (coords != null && coords.size() >= 2) {
                w.longitude = ((Decimal) coords[0]).doubleValue();
                w.latitude  = ((Decimal) coords[1]).doubleValue();
            }
        }

        return w;
    }

    private static CommuneWrapper mapToCommune(Map<String, Object> m) {
        CommuneWrapper c = new CommuneWrapper();
        c.code            = (String) m.get('code');
        c.nom             = (String) m.get('nom');
        c.population      = m.get('population') != null
            ? Integer.valueOf(m.get('population')) : null;
        c.surface         = m.get('surface') != null
            ? ((Decimal) m.get('surface')).doubleValue() : null;
        c.codeDepartement = (String) m.get('codeDepartement');
        c.codeRegion      = (String) m.get('codeRegion');

        List<Object> cps = (List<Object>) m.get('codesPostaux');
        if (cps != null && !cps.isEmpty()) {
            c.codePostal = (String) cps[0];
        }

        return c;
    }

    public class EpciWrapper {
        @AuraEnabled public String  code;
        @AuraEnabled public String  nom;
        @AuraEnabled public Integer populationTotale;
        @AuraEnabled public String  departements;
        @AuraEnabled public Integer nombreCommunes;
        @AuraEnabled public Double  latitude;
        @AuraEnabled public Double  longitude;
    }

    public class CommuneWrapper {
        @AuraEnabled public String  code;
        @AuraEnabled public String  nom;
        @AuraEnabled public String  codePostal;
        @AuraEnabled public Integer population;
        @AuraEnabled public Double  surface;
        @AuraEnabled public String  codeDepartement;
        @AuraEnabled public String  codeRegion;
    }

    public class EpciApiException extends Exception {}
}
