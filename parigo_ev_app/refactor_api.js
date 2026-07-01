const fs = require('fs');
const path = require('path');

function walkDir(dir, callback) {
  fs.readdirSync(dir).forEach(f => {
    const dirPath = path.join(dir, f);
    if (f === 'api_client.dart') return; // Skip our new file
    if (fs.statSync(dirPath).isDirectory()) walkDir(dirPath, callback);
    else if (dirPath.endsWith('.dart')) callback(dirPath);
  });
}

walkDir(path.join(__dirname, 'lib'), (filePath) => {
  let content = fs.readFileSync(filePath, 'utf8');
  let changed = false;

  if (/http\s*\.\s*(get|post|delete|put)\s*\(/.test(content)) {
    content = content.replace(/http\s*\.\s*get\s*\(/g, 'ApiClient.get(');
    content = content.replace(/http\s*\.\s*post\s*\(/g, 'ApiClient.post(');
    content = content.replace(/http\s*\.\s*delete\s*\(/g, 'ApiClient.delete(');
    content = content.replace(/http\s*\.\s*put\s*\(/g, 'ApiClient.put(');
    
    // Add import if not exists
    const importStr = "import 'package:parigo_ev_app/core/api_client.dart';\n";
    if (!content.includes('api_client.dart')) {
      const lastImportIndex = content.lastIndexOf("import ");
      if (lastImportIndex !== -1) {
         const endOfImport = content.indexOf(';', lastImportIndex) + 1;
         content = content.slice(0, endOfImport) + '\n' + importStr + content.slice(endOfImport);
      } else {
         content = importStr + content;
      }
    }
    changed = true;
  }

  if (changed) {
    fs.writeFileSync(filePath, content, 'utf8');
    console.log('Updated', filePath);
  }
});
