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

// The exact order of columns in lizmap.observations (excluding geom)
const tableColumnOrder = [
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
  'lon'
];

const rows = [];

fs.createReadStream(inputCsv)
  .pipe(csv())
  .on('data', (row) => {
    // Normalize header names to lowercase for matching
    const normalizedRow = {};
    for (const key in row) {
      normalizedRow[key.toLowerCase()] = row[key];
    }

    // Add symbol_code
    normalizedRow.symbol_code = mapSymbolCode(normalizedRow.deficiencies);

    rows.push(normalizedRow);
  })
  .on('end', () => {
    // Ensure all rows follow the table's column order
    const orderedRows = rows.map(row =>
      tableColumnOrder.reduce((acc, col) => {
        acc[col] = row[col] || '';
        return acc;
      }, {})
    );

    const opts = { fields: tableColumnOrder };
    const csvData = parse(orderedRows, opts);
    fs.writeFileSync(outputCsv, csvData);
    console.log(`✅ New CSV saved as ${outputCsv}`);
  });
