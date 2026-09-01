const pumpDisplay = document.getElementById('pumpDisplay');
const selectionScreen = document.getElementById('selectionScreen');
const fuelScreen = document.getElementById('fuelScreen');
const fuelOptions = document.getElementById('fuelOptions');
const costValue = document.getElementById('costValue');
const tankValue = document.getElementById('tankValue');
const meterFill = document.getElementById('meterFill');
const bankBalance = document.getElementById('bankBalance');
const cashBalance = document.getElementById('cashBalance');
const pricePerGallon = document.getElementById('pricePerGallon');
const gallonsValue = document.getElementById('gallonsValue');
const selectedGrade = document.getElementById('selectedGrade');
const selectedName = document.getElementById('selectedName');
const gradePill = document.getElementById('gradePill');
let currencySymbol = '$';
let numberLocale = 'en-US';
let decimalPlaces = 2;
const cancelSelection = document.getElementById('cancelSelection');
const brandTitle = document.getElementById('brandTitle');
const brandSubtitle = document.getElementById('brandSubtitle');

// Keep the NUI hidden until Lua explicitly opens it.
pumpDisplay.classList.remove('visible');
selectionScreen.classList.remove('visible');
fuelScreen.classList.remove('visible');

function applyConfig(ui) {
    if (!ui) return;
    if (ui.Title) brandTitle.textContent = ui.Title;
    if (ui.Currency) currencySymbol = ui.Currency;
    if (ui.Locale) numberLocale = ui.Locale;
    if (Number.isFinite(Number(ui.DecimalPlaces))) decimalPlaces = Number(ui.DecimalPlaces);
    if (ui.Subtitle) brandSubtitle.textContent = ui.Subtitle;
    if (ui.Text) {
        document.querySelector('.screen-kicker').textContent = ui.Text.SelectKicker || 'PLEASE SELECT';
        document.querySelector('.screen-title').textContent = ui.Text.SelectTitle || 'FUEL TYPE';
        document.querySelector('.screen-sub').textContent = ui.Text.SelectSubtitle || 'Choose your grade before fueling';
        document.querySelector('.fuel-header .screen-kicker').textContent = ui.Text.SelectedKicker || 'SELECTED FUEL';
        document.querySelector('.side-card .label').textContent = ui.Text.TankLabel || 'Vehicle tank';
        document.querySelector('.amount-box:nth-child(1) .label').textContent = ui.Text.PriceLabel || 'Price per gallon';
        document.querySelector('.gallons-box .label').textContent = ui.Text.GallonsLabel || 'Gallons';
        document.querySelector('.amount-box.primary .label').textContent = ui.Text.TotalLabel || 'Total price';
        document.querySelector('.balance-card:nth-child(1) .label').textContent = ui.Text.BankLabel || 'Bank balance';
        document.querySelector('.balance-card:nth-child(2) .label').textContent = ui.Text.CashLabel || 'Cash balance';
        cancelSelection.textContent = ui.Text.Close || 'CLOSE';
    }
    if (ui.Theme) {
        const root = document.documentElement;
        if (ui.Theme.Red) root.style.setProperty('--red', ui.Theme.Red);
        if (ui.Theme.RedDark) root.style.setProperty('--red-dark', ui.Theme.RedDark);
        if (ui.Theme.White) root.style.setProperty('--white', ui.Theme.White);
        if (ui.Theme.Muted) root.style.setProperty('--muted', ui.Theme.Muted);
    }
}

function cleanNumber(value) {
    const parsed = Number.parseFloat(value);
    return Number.isFinite(parsed) ? parsed : 0;
}

function money(value) {
    return cleanNumber(value).toLocaleString(numberLocale, {
        minimumFractionDigits: decimalPlaces,
        maximumFractionDigits: decimalPlaces
    });
}

function setFuelLevel(value) {
    const level = Math.max(0, Math.min(100, cleanNumber(value)));
    tankValue.textContent = level.toFixed(2);
    meterFill.style.width = `${level}%`;
}

function setCost(value) { costValue.textContent = money(value); }
function setBank(value) { bankBalance.textContent = `${currencySymbol}${money(value)}`; }
function setCash(value) { cashBalance.textContent = `${currencySymbol}${money(value)}`; }
function setPricePerGallon(value) { pricePerGallon.textContent = money(value); }
function setGallons(value) { gallonsValue.textContent = cleanNumber(value).toFixed(decimalPlaces); }

function setBalances(bank, cash) {
    if (bank !== undefined) setBank(bank);
    if (cash !== undefined) setCash(cash);
}

function setFuelType(grade, name, price) {
    selectedGrade.textContent = grade;
    selectedName.textContent = String(name || 'UNLEADED GASOLINE').toUpperCase();
    gradePill.textContent = `${grade} ${name || ''}`.toUpperCase();
    setPricePerGallon(price);
}

function closePumpUI() {
    const summary = document.getElementById('paymentSummary');
    if (summary) summary.classList.remove('visible');
    fetch(`https://${GetParentResourceName()}/cancelFuelSelection`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: '{}'
    });
}

cancelSelection.addEventListener('click', closePumpUI);
const summaryClose = document.getElementById('summaryClose');
if (summaryClose) summaryClose.addEventListener('click', closePumpUI);

window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && pumpDisplay.classList.contains('visible')) {
        cancelSelection.click();
    }
});

function showSelection(options) {
    fuelOptions.innerHTML = '';
    (options || []).forEach((fuel) => {
        const button = document.createElement('button');
        button.className = 'fuel-option';
        button.type = 'button';
        button.innerHTML = `
            <div class="fuel-grade">${fuel.grade}</div>
            <div class="fuel-details">
                <div class="fuel-option-name">${fuel.name}</div>
                <div class="fuel-option-sub">${fuel.description || 'Unleaded gasoline'}</div>
            </div>
            <div class="fuel-option-price">${currencySymbol}${money(fuel.price)}<span>/GAL</span></div>
        `;
        button.addEventListener('click', () => {
            fetch(`https://${GetParentResourceName()}/selectFuel`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({ grade: fuel.grade })
            });
        });
        fuelOptions.appendChild(button);
    });
}

window.addEventListener('message', function(event) {
    const item = event.data || {};

    if (item.type === 'uiConfig') { applyConfig(item.ui); }

    if (item.type === 'showSelection') {
        pumpDisplay.classList.add('visible');
        selectionScreen.classList.add('visible');
        fuelScreen.classList.remove('visible');
        document.getElementById('paymentSummary').classList.remove('visible');
        showSelection(item.fuels || []);
        setBalances(item.bankBalance, item.cashBalance);
    }

    if (item.type === 'status') {
        const active = !!item.status;
        pumpDisplay.classList.toggle('visible', active);
        selectionScreen.classList.toggle('visible', !!item.selection && active);
        fuelScreen.classList.toggle('visible', active && !item.selection);
    }

    if (item.type === 'fuelSelected') {
        pumpDisplay.classList.add('visible');
        selectionScreen.classList.remove('visible');
        document.getElementById('paymentSummary').classList.remove('visible');
        fuelScreen.classList.add('visible');
        setFuelType(item.grade, item.name, item.price);
        setCost(0);
        setGallons(0);
        if (item.fuelTank !== undefined) setFuelLevel(item.fuelTank);
        setBalances(item.bankBalance, item.cashBalance);
    }

    if (item.type === 'update') {
        setCost(item.fuelCost);
        setFuelLevel(item.fuelTank);
        if (item.gallons !== undefined) setGallons(item.gallons);
        setBalances(item.bankBalance, item.cashBalance);
        if (item.pricePerGallon !== undefined) setPricePerGallon(item.pricePerGallon);
    }


    if (item.type === 'fuelFinished') {
        // Keep the regular refill screen visible after fueling completes.
        // Grade selection is never reopened here.
        pumpDisplay.classList.add('visible');
        selectionScreen.classList.remove('visible');
        document.getElementById('paymentSummary').classList.remove('visible');
        fuelScreen.classList.add('visible');
        if (item.grade !== undefined) setFuelType(item.grade, item.name, item.price);
        if (item.fuelTank !== undefined) setFuelLevel(item.fuelTank);
        if (item.fuelCost !== undefined) setCost(item.fuelCost);
        if (item.gallons !== undefined) setGallons(item.gallons);
        setBalances(item.bankBalance, item.cashBalance);
    }

    if (item.type === 'paymentSummary') {
        pumpDisplay.classList.add('visible');
        selectionScreen.classList.remove('visible');
        fuelScreen.classList.remove('visible');
        document.getElementById('paymentSummary').classList.add('visible');
        document.getElementById('summaryAmount').textContent = `${currencySymbol}${money(item.amount)}`;
        document.getElementById('summaryGallons').textContent = `${cleanNumber(item.gallons).toFixed(decimalPlaces)} GAL`;
        document.getElementById('summaryGrade').textContent = item.grade ? `${item.grade} ${String(item.name || '').toUpperCase()}` : 'FUEL';
        setBalances(item.bankBalance, item.cashBalance);
    }

    if (item.type === 'status') {
        const summary = document.getElementById('paymentSummary');
        if (summary) summary.classList.remove('visible');
    }

    if (item.type === 'balances') setBalances(item.bankBalance, item.cashBalance);
    if (item.type === 'bank') setBank(item.bankBalance);
    if (item.type === 'cash') setCash(item.cashBalance);
    if (item.type === 'price') setPricePerGallon(item.pricePerGallon);
});


// Tell the Lua side that the NUI page is loaded and ready.
fetch(`https://${GetParentResourceName()}/uiReady`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: '{}'
}).catch(() => {});


const jerryDisplay = document.getElementById('jerryDisplay');
const jerryFill = document.getElementById('jerryFill');
const jerryPercent = document.getElementById('jerryPercent');
const jerryStatusText = document.getElementById('jerryStatusText');
const jerryCanFill = document.getElementById('jerryCanFill');
const jerryCanPercent = document.getElementById('jerryCanPercent');

function setJerryCanLevel(value) {
    const level = Math.max(0, Math.min(100, cleanNumber(value)));
    if (jerryCanFill) jerryCanFill.style.width = `${level}%`;
    if (jerryCanPercent) jerryCanPercent.textContent = `${Math.floor(level)}%`;
}

function setJerryFuel(value) {
    const level = Math.max(0, Math.min(100, cleanNumber(value)));
    jerryFill.style.width = `${level}%`;
    jerryPercent.textContent = `${Math.floor(level)}%`;
    jerryStatusText.textContent = level >= 100 ? 'TANK FULL' : 'FUEL LEVEL';
}

window.addEventListener('message', function(event) {
    const item = event.data || {};

    if (item.type === 'jerryStatus') {
        const active = !!item.status;
        jerryDisplay.classList.toggle('visible', active);
        if (item.fuel !== undefined) setJerryFuel(item.fuel);
        if (item.canPercent !== undefined) setJerryCanLevel(item.canPercent);
    }

    if (item.type === 'jerryUpdate') {
        jerryDisplay.classList.add('visible');
        setJerryFuel(item.fuel);
        if (item.canPercent !== undefined) setJerryCanLevel(item.canPercent);
    }
});
