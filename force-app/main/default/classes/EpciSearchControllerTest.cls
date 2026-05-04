@IsTest
public class EpciSearchControllerTest {

    private class GeoMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            String ep = req.getEndpoint();
            if (ep.contains('/communes')) {
                res.setBody(
                    '[{"code":"31555","nom":"Toulouse","codesPostaux":["31000"],' +
                    '"population":493465,"surface":118.45,"codeDepartement":"31","codeRegion":"76"}]'
                );
            } else if (ep.contains('?nom=')) {
                res.setBody(
                    '[{"code":"243100518","nom":"Toulouse Métropole",' +
                    '"populationTotale":783916,"codesDepartements":["31"]}]'
                );
            } else {
                res.setBody(
                    '{"code":"243100518","nom":"Toulouse Métropole",' +
                    '"populationTotale":783916,"codesDepartements":["31"],' +
                    '"codesCommunes":["31555","31069"],' +
                    '"centre":{"type":"Point","coordinates":[1.4179,43.6417]}}'
                );
            }
            return res;
        }
    }

    @IsTest
    static void searchEpci_withValidTerm_returnsResults() {
        Test.setMock(HttpCalloutMock.class, new GeoMock());
        Test.startTest();
        List<EpciGeoApiService.EpciWrapper> results = EpciSearchController.searchEpci('toulouse');
        Test.stopTest();
        Assert.areEqual(1, results.size());
        Assert.areEqual('Toulouse Métropole', results[0].nom);
    }

    @IsTest
    static void searchEpci_shortTerm_returnsEmpty() {
        Test.startTest();
        List<EpciGeoApiService.EpciWrapper> results = EpciSearchController.searchEpci('T');
        Test.stopTest();
        Assert.isTrue(results.isEmpty());
    }

    @IsTest
    static void getEpciDetail_returnsFullWrapper() {
        Test.setMock(HttpCalloutMock.class, new GeoMock());
        Test.startTest();
        EpciGeoApiService.EpciWrapper detail = EpciSearchController.getEpciDetail('243100518');
        Test.stopTest();
        Assert.areEqual('Toulouse Métropole', detail.nom);
        Assert.areEqual(2, detail.nombreCommunes);
        Assert.isTrue(Math.abs(detail.latitude  - 43.6417) < 0.0001, 'Latitude mismatch');
        Assert.isTrue(Math.abs(detail.longitude - 1.4179)  < 0.0001, 'Longitude mismatch');
    }

    @IsTest
    static void getCommunes_returnsAllFields() {
        Test.setMock(HttpCalloutMock.class, new GeoMock());
        Test.startTest();
        List<EpciGeoApiService.CommuneWrapper> communes =
            EpciSearchController.getCommunes('243100518');
        Test.stopTest();
        Assert.areEqual(1, communes.size());
        Assert.areEqual('Toulouse', communes[0].nom);
        Assert.areEqual('31',       communes[0].codeDepartement);
        Assert.areEqual('76',       communes[0].codeRegion);
        Assert.isTrue(Math.abs(communes[0].surface - 118.45) < 0.01, 'Surface mismatch');
    }

    @IsTest
    static void saveEpci_createsRecordWithAllFields() {
        Test.startTest();
        EPCI__c record = EpciSearchController.saveEpci(
            'Toulouse Métropole', '243100518', 783916, '31', 71, 43.6417, 1.4179, null
        );
        Test.stopTest();
        Assert.areEqual('Toulouse Métropole',   record.Name);
        Assert.areEqual('243100518',            record.Code_EPCI__c);
        Assert.areEqual(Decimal.valueOf(783916), record.Population_Totale__c);
        Assert.areEqual(71,                     record.Nombre_Communes__c);
        Assert.isNotNull(record.Localisation__Latitude__s);
    }

    @IsTest
    static void saveEpci_upsertDoesNotDuplicate() {
        Test.startTest();
        EpciSearchController.saveEpci('Toulouse Métropole', '243100518', 783916, '31', 71, null, null, null);
        EpciSearchController.saveEpci('Toulouse Métropole', '243100518', 800000, '31', 72, null, null, null);
        Test.stopTest();
        Assert.areEqual(1, [SELECT COUNT() FROM EPCI__c WHERE Code_EPCI__c = '243100518']);
    }
}
