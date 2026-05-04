@IsTest
public class EpciGeoApiServiceTest {

    private static final String SEARCH_BODY =
        '[{"code":"243100518","nom":"Toulouse Métropole",' +
        '"populationTotale":783916,"codesDepartements":["31"]}]';

    private static final String DETAIL_BODY =
        '{"code":"243100518","nom":"Toulouse Métropole",' +
        '"populationTotale":783916,"codesDepartements":["31"],' +
        '"codesCommunes":["31555","31069","31149"],' +
        '"centre":{"type":"Point","coordinates":[1.4179,43.6417]}}';

    private static final String COMMUNES_BODY =
        '[{"code":"31555","nom":"Toulouse","codesPostaux":["31000","31400"],' +
        '"population":493465,"surface":118.45,"codeDepartement":"31","codeRegion":"76"},' +
        '{"code":"31069","nom":"Blagnac","codesPostaux":["31700"],' +
        '"population":24045,"surface":21.3,"codeDepartement":"31","codeRegion":"76"}]';

    private class OkMock implements HttpCalloutMock {
        private String body;
        OkMock(String body) { this.body = body; }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody(this.body);
            return res;
        }
    }

    private class ErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(503);
            res.setBody('Service unavailable');
            return res;
        }
    }

    @IsTest
    static void searchByNom_returnsEpcis() {
        Test.setMock(HttpCalloutMock.class, new OkMock(SEARCH_BODY));
        Test.startTest();
        List<EpciGeoApiService.EpciWrapper> results = EpciGeoApiService.searchByNom('toulouse');
        Test.stopTest();
        Assert.areEqual(1, results.size());
        Assert.areEqual('Toulouse Métropole', results[0].nom);
        Assert.areEqual('243100518', results[0].code);
        Assert.areEqual(783916, results[0].populationTotale);
        Assert.areEqual('31', results[0].departements);
    }

    @IsTest
    static void getByCode_returnsFullDetail() {
        Test.setMock(HttpCalloutMock.class, new OkMock(DETAIL_BODY));
        Test.startTest();
        EpciGeoApiService.EpciWrapper detail = EpciGeoApiService.getByCode('243100518');
        Test.stopTest();
        Assert.areEqual('Toulouse Métropole', detail.nom);
        Assert.areEqual(3, detail.nombreCommunes);
        Assert.isNotNull(detail.latitude,  'Latitude attendue');
        Assert.isNotNull(detail.longitude, 'Longitude attendue');
        Assert.isTrue(Math.abs(detail.latitude  - 43.6417) < 0.0001, 'Latitude mismatch');
        Assert.isTrue(Math.abs(detail.longitude - 1.4179)  < 0.0001, 'Longitude mismatch');
    }

    @IsTest
    static void getCommunesByCode_returnsAllFields() {
        Test.setMock(HttpCalloutMock.class, new OkMock(COMMUNES_BODY));
        Test.startTest();
        List<EpciGeoApiService.CommuneWrapper> communes =
            EpciGeoApiService.getCommunesByCode('243100518');
        Test.stopTest();
        Assert.areEqual(2, communes.size());
        Assert.areEqual('Toulouse',  communes[0].nom);
        Assert.areEqual('31000',     communes[0].codePostal);
        Assert.areEqual(493465,      communes[0].population);
        Assert.isTrue(Math.abs(communes[0].surface - 118.45) < 0.01, 'Surface mismatch');
        Assert.areEqual('31',        communes[0].codeDepartement);
        Assert.areEqual('76',        communes[0].codeRegion);
    }

    @IsTest
    static void doGet_onError_throwsEpciApiException() {
        Test.setMock(HttpCalloutMock.class, new ErrorMock());
        Test.startTest();
        Boolean thrown = false;
        try {
            EpciGeoApiService.searchByNom('toulouse');
        } catch (EpciGeoApiService.EpciApiException e) {
            thrown = true;
            Assert.isTrue(e.getMessage().contains('503'));
        }
        Test.stopTest();
        Assert.isTrue(thrown, 'EpciApiException attendue');
    }

    @IsTest
    static void searchByNom_emptyResponse_returnsEmptyList() {
        Test.setMock(HttpCalloutMock.class, new OkMock('[]'));
        Test.startTest();
        List<EpciGeoApiService.EpciWrapper> results = EpciGeoApiService.searchByNom('inconnu');
        Test.stopTest();
        Assert.isTrue(results.isEmpty());
    }
}
