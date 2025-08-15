const fs = require('fs');
const path = require('path');
const csv = require('csv-parser');
const { parse } = require('json2csv');

// Manually change seed target
const seedTarget = '001';

// Input & output file paths
const inputCsv = path.join(__dirname, 'db', 'seeds', seedTarget, `${seedTarget}.csv`);
const outputCsv = path.join(__dirname, 'db', 'seeds', seedTarget, `${seedTarget}_with_symbol_code.csv`);

console.log(`Input CSV: ${inputCsv}`);
console.log(`Output CSV: ${outputCsv}`);

// Columns in the same order as Postgres table
const pgColumns = [
  'id',
  'portfolio_name',
  'project_name',
  'site_name',
  'owner_organization',
  'service_organization',
  'data_source',
  'inspection_date',
  'deficiencies',
  'description',
  'symbol_code',
  'lat',
  'lon',
  'geom'
];

// Mapping function
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

// Type formatting for Postgres
function formatForPostgres(column, value) {
  if (value === undefined || value === null || value === '') return '';

  switch (column) {
    case 'id': // INTEGER
      return parseInt(value, 10) || '';
    case 'inspection_date': // DATE (YYYY-MM-DD)
      return new Date(value).toISOString().split('T')[0];
    case 'lat': // DOUBLE PRECISION
    case 'lon':
      return parseFloat(value) || '';
    case 'geom': // GEOMETRY(Point, 3857) — leave empty, can be generated in SQL
      return '';
    default: // TEXT columns
      return String(value).trim();
  }
}

const rows = [];

fs.createReadStream(inputCsv)
  .pipe(csv())
  .on('data', (row) => {
    const newRow = {};
    pgColumns.forEach((col) => {
      if (col === 'symbol_code') {
        newRow[col] = mapSymbolCode(row.Deficiencies || row.deficiencies);
      } else {
        newRow[col] = formatForPostgres(col, row[col] || row[col?.toLowerCase()]);
      }
    });
    rows.push(newRow);
  })
  .on('end', () => {
    const opts = { fields: pgColumns };
    const csvData = parse(rows, opts);
    fs.writeFileSync(outputCsv, csvData);
    console.log(`✅ New CSV saved as ${outputCsv} with correct column order and Postgres-compatible types`);
  });
