const fs = require('fs');
const path = require('path');
const csv = require('csv-parser');
const { parse } = require('json2csv');

// Manually change seed target
const seedTarget = '001';

// Input & output file paths
const inputCsv = path.join(__dirname, 'db', 'seeds', seedTarget, `${seedTarget}_original.csv`);
const outputCsv = path.join(__dirname, 'db', 'seeds', seedTarget, `${seedTarget}_with_symbol_code.csv`);

console.log(`Input CSV: ${inputCsv}`);
console.log(`Output CSV: ${outputCsv}`);

// Columns in the same order as Postgres table (excluding geom because staging drops it)
const pgColumns = [
  'id',
  'portfolio_name',
  'project_name',
  'site_name',
  'owner_organization',
  'service_organization',
  'data_source',
  'date',
  'deficiencies',
  'description',
  'symbol_code',
  'lat',
  'lon'
];

// ---- helpers ----
function mapSymbolCode(deficiency) {
  const text = (deficiency || '').toLowerCase();
  if (text.includes('erosion')) return 'erosion';
  if (text.includes('exposure')) return 'exposure';
  if (text.includes('forest fire')) return 'forest_fire';
  if (text.includes('geohaz')) return 'geohaz';
  if (text.includes('observed spill')) return 'observed_spill';
  if (text.includes('over growth')) return 'over_growth';
  if (text.includes('public enc')) return 'public_enc';
  if (text.includes('sign missing')) return 'sign_missing';
  if (text.includes('third party')) return 'third_party';
  if (text.includes('above ground pipe')) return 'above_ground_pipe';
  if (text.includes('active construction')) return 'active_construction';
  if (text.includes('riser')) return 'riser';
  if (text.includes('open_ditch') || text.includes('open ditch')) return 'open_ditch';
  if (text.includes('patterned holes')) return 'patterned_holes';
  if (text.includes('pipe bridge')) return 'pipe_bridge';
  if (text.includes('beaver')) return 'beaver';
  return 'other';
}

// robust DATE -> YYYY-MM-DD
function toISODate(value) {
  const s = String(value || '').trim();
  if (!s) return '';

  // YYYY/MM/DD or YYYY-MM-DD
  let m = s.match(/^(\d{4})[\/-](\d{1,2})[\/-](\d{1,2})$/);
  if (m) {
    const [, y, mo, d] = m;
    return `${y}-${mo.padStart(2, '0')}-${d.padStart(2, '0')}`;
  }

  // M/D/YYYY or MM-DD-YYYY
  m = s.match(/^(\d{1,2})[\/-](\d{1,2})[\/-](\d{4})$/);
  if (m) {
    const [, mo, d, y] = m;
    return `${y}-${mo.padStart(2, '0')}-${d.padStart(2, '0')}`;
  }

  // Fallback to Date parsing
  const dt = new Date(s);
  if (!isNaN(dt)) return dt.toISOString().slice(0, 10);

  return '';
}

function formatForPostgres(column, value) {
  const v = value === undefined || value === null ? '' : String(value).trim();

  switch (column) {
    case 'id': {
      const n = parseInt(v, 10);
      return Number.isFinite(n) ? n : '';
    }
    case 'date':
      return toISODate(v);
    case 'lat':
    case 'lon': {
      const f = parseFloat(v);
      return Number.isFinite(f) ? f : '';
    }
    default:
      return v; // TEXT columns
  }
}

// pick first defined/non-empty from aliases
function pick(row, ...keys) {
  for (const k of keys) {
    const val = row[k];
    if (val !== undefined && val !== null && String(val).trim() !== '') return val;
  }
  return '';
}

// ---- processing ----
const rows = [];

// Normalize headers to lowercase once using mapHeaders.
// This turns "Data_Source" -> "data_source", "Date" -> "date", etc.
fs.createReadStream(inputCsv)
  .pipe(csv({ mapHeaders: ({ header }) => header.trim().toLowerCase() }))
  .on('data', (row) => {
    // Build one output row in DB order, mapping aliases
    const out = {};

    out.id = formatForPostgres('id', pick(row, 'id'));
    out.portfolio_name = formatForPostgres('portfolio_name', pick(row, 'portfolio_name'));
    out.project_name = formatForPostgres('project_name', pick(row, 'project_name'));
    out.site_name = formatForPostgres('site_name', pick(row, 'site_name'));
    out.owner_organization = formatForPostgres('owner_organization', pick(row, 'owner_organization'));
    out.service_organization = formatForPostgres('service_organization', pick(row, 'service_organization'));

    // handles "Data_Source" -> "data_source"
    out.data_source = formatForPostgres('data_source', pick(row, 'data_source', 'datasource', 'source'));

    // handles "Date" -> "date"
    out.date = formatForPostgres('date', pick(row, 'date', 'date'));

    out.deficiencies = formatForPostgres('deficiencies', pick(row, 'deficiencies'));
    out.description = formatForPostgres('description', pick(row, 'description', 'desc'));

    // symbol_code derived from deficiencies
    out.symbol_code = mapSymbolCode(out.deficiencies);

    // coordinates (support aliases just in case)
    out.lat = formatForPostgres('lat', pick(row, 'lat', 'latitude', 'y'));
    out.lon = formatForPostgres('lon', pick(row, 'lon', 'longitude', 'x'));

    rows.push(out);
  })
  .on('end', () => {
    const csvData = parse(rows, { fields: pgColumns });
    fs.writeFileSync(outputCsv, csvData);
    console.log(`✅ New CSV saved as ${outputCsv}`);
  })
  .on('error', (err) => {
    console.error('CSV read error:', err);
    process.exit(1);
  });
