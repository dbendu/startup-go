const path = require('path');
const fs = require('fs');
const solc = require('solc');

const contractsPath = path.resolve(__dirname, '../', 'contracts');
const buildPath = path.resolve(__dirname, '../', 'build');

fs.rmSync(buildPath, { recursive: true, force: true });

const composeCompilerInput = () => {
    const contractsFiles = fs.readdirSync(contractsPath)
        .map((file) => path.join(contractsPath, file));

    const compilerInput = {
        language: 'Solidity',
        sources: { },
        settings: {
            optimizer: {
                enabled: true,
                runs: 2^31
            },
            outputSelection: {
                "*": {
                    "*": [ "abi", "evm.bytecode.object" ]
                },
            }
        }
    };

    contractsFiles.forEach(fileName => {
        const contractName = path.basename(fileName);
        const fileContent = fs.readFileSync(fileName, 'utf8');

        compilerInput.sources[contractName] = { content: fileContent };
    });

    return compilerInput;
}

function findImports(importPath) {
    const file = path.join(contractsPath, importPath);
    return { contents: fs.readFileSync(file, 'utf8') };
}

const compilerInput = composeCompilerInput();
const compiled =solc.compile(JSON.stringify(compilerInput), { import: findImports });

const contracts = Object.values(JSON.parse(compiled).contracts);

const Campaign = {
    abi: contracts[0].Campaign.abi,
    bytecode: contracts[0].Campaign.evm.bytecode.object
};

fs.mkdirSync(buildPath);

fs.writeFileSync(
    path.join(buildPath, 'Campaign.json'),
    JSON.stringify(Campaign, null, 4));


console.log('OK');