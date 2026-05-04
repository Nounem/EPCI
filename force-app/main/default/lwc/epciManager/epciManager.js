import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchEpci    from '@salesforce/apex/EpciSearchController.searchEpci';
import getEpciDetail from '@salesforce/apex/EpciSearchController.getEpciDetail';
import getCommunes   from '@salesforce/apex/EpciSearchController.getCommunes';
import saveEpci      from '@salesforce/apex/EpciSearchController.saveEpci';
import saveCommunes  from '@salesforce/apex/EpciSearchController.saveCommunes';

const DEBOUNCE_MS = 300;
const MIN_CHARS   = 2;

const COMMUNE_COLUMNS = [
    { label: 'Commune',       fieldName: 'nom' },
    { label: 'Code INSEE',    fieldName: 'code' },
    { label: 'Code postal',   fieldName: 'codePostal' },
    { label: 'Département',   fieldName: 'codeDepartement' },
    { label: 'Région',        fieldName: 'codeRegion' },
    {
        label: 'Population', fieldName: 'population', type: 'number',
        typeAttributes: { minimumFractionDigits: 0, maximumFractionDigits: 0 }
    },
    {
        label: 'Surface (km²)', fieldName: 'surface', type: 'number',
        typeAttributes: { minimumFractionDigits: 2, maximumFractionDigits: 2 }
    }
];

export default class EpciManager extends LightningElement {

    @api recordId = null;

    @track searchTerm        = '';
    @track results           = [];
    @track selectedEpci      = null;
    @track communes          = [];
    @track isLoading         = false;
    @track isLoadingDetail   = false;
    @track isLoadingCommunes = false;
    @track isSaving          = false;
    @track error             = null;
    @track showCommunes      = false;
    @track creerCommunes     = false;

    communeColumns = COMMUNE_COLUMNS;
    _timer = null;

    get showResults() {
        return this.results.length > 0;
    }

    get sectionClass() {
        return this.showCommunes ? 'slds-section slds-is-open' : 'slds-section';
    }

    get saveLabel() {
        return this.isSaving ? 'Enregistrement...' : 'Enregistrer';
    }

    handleCreerCommunesChange(event) {
        this.creerCommunes = event.target.checked;
        if (this.creerCommunes && this.communes.length === 0) {
            this._loadCommunes();
        }
    }

    handleSearchChange(event) {
        this.searchTerm   = event.target.value;
        this.error        = null;
        this.selectedEpci = null;
        this.results      = [];

        clearTimeout(this._timer);
        if (this.searchTerm.length < MIN_CHARS) return;
        this._timer = setTimeout(() => this._search(), DEBOUNCE_MS);
    }

    async _search() {
        this.isLoading = true;
        try {
            const raw    = await searchEpci({ nom: this.searchTerm });
            this.results = raw.map(r => this._enrichSearch(r));
        } catch (e) {
            this.error = 'Erreur lors de la recherche. Vérifiez votre connexion.';
        } finally {
            this.isLoading = false;
        }
    }

    async handleSelectEpci(event) {
        const code = event.currentTarget.dataset.code;
        this.results          = [];
        this.selectedEpci     = null;
        this.communes         = [];
        this.showCommunes     = false;
        this.error            = null;
        this.isLoadingDetail  = true;
        try {
            const detail      = await getEpciDetail({ code });
            this.selectedEpci = this._enrichDetail(detail);
        } catch (e) {
            this.error = 'Impossible de charger le détail de cet EPCI.';
        } finally {
            this.isLoadingDetail = false;
        }
    }

    async toggleCommunes() {
        this.showCommunes = !this.showCommunes;
        if (this.showCommunes && this.communes.length === 0) {
            await this._loadCommunes();
        }
    }

    async _loadCommunes() {
        this.isLoadingCommunes = true;
        try {
            this.communes = await getCommunes({ code: this.selectedEpci.code });
            if (!this.selectedEpci.nombreCommunes) {
                this.selectedEpci = { ...this.selectedEpci, nombreCommunes: this.communes.length };
            }
        } catch (e) {
            this.error = 'Impossible de charger les communes membres.';
        } finally {
            this.isLoadingCommunes = false;
        }
    }

    async handleSave() {
        this.isSaving = true;
        try {
            const record = await saveEpci({
                nom:              this.selectedEpci.nom,
                code:             this.selectedEpci.code,
                populationTotale: this.selectedEpci.populationTotale,
                departements:     this.selectedEpci.departements,
                nombreCommunes:   this.selectedEpci.nombreCommunes,
                latitude:         this.selectedEpci.latitude,
                longitude:        this.selectedEpci.longitude,
                accountId:        this.recordId
            });

            if (this.creerCommunes) {
                if (this.communes.length === 0) {
                    await this._loadCommunes();
                }
                await saveCommunes({
                    epciId:       record.Id,
                    communesJson: JSON.stringify(this.communes)
                });
            }

            const nbCommunes = this.creerCommunes ? ` et ${this.communes.length} commune(s) créée(s).` : '.';
            this.dispatchEvent(new ShowToastEvent({
                title:   'Enregistré',
                message: `"${this.selectedEpci.nom}" a été enregistré${nbCommunes}`,
                variant: 'success'
            }));
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({
                title:   'Erreur',
                message: 'Impossible d\'enregistrer cet EPCI.',
                variant: 'error'
            }));
        } finally {
            this.isSaving = false;
        }
    }

    _enrichSearch(r) {
        return {
            ...r,
            populationFormatee: this._formatNumber(r.populationTotale)
        };
    }

    _enrichDetail(r) {
        return {
            ...r,
            populationFormatee: this._formatNumber(r.populationTotale),
            latitudeFormatee:   r.latitude  != null ? Number(r.latitude).toFixed(6)  : 'N/A',
            longitudeFormatee:  r.longitude != null ? Number(r.longitude).toFixed(6) : 'N/A'
        };
    }

    _formatNumber(val) {
        return val != null ? new Intl.NumberFormat('fr-FR').format(val) : 'N/A';
    }
}
