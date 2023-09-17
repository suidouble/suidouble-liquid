const argv = require('minimist')(process.argv.slice(2));

let selectedChain = argv.chain || 'local';

const settings = {
    "local": {
        "phrase": "coin coin coin coin coin coin coin coin coin coin coin coin coin coin coin coin coin coin coin coin coin coin coin coin",
        "packageId": "0x27a912b20e32a7f07c387392121b1d6f2c9e835c1b1c185d8528fe81135376fa",
        "firstVPackageId": "",
        "liquidStoreId": "0x69f8118559a6dd2c29ce0fdb83f576b9e25682daaeeda1ec041bcccaad8d8708",
        "adminCapId": "0x4fccdf4152cb5e6132dafcd808ae6b667d18cd49c0bd65ebef3296186c1e07e3",
    },
    "mainnet": {
        "phrase": "", // set it as cli parameter
        "packageId": "0x7372d1e5655441ccf754a637bf9f9e37a8ca113a2fa00f6e2b8f793abbfbdccd",
        "firstVPackageId": "0x67e77b4e79e8c157e42c18eecf68e25047f6f95e657bd65387189411f2898ce3",
        "liquidStoreId": "0x78d9273a9f774a2bd6c35cf79fbcf4029ee076cc249207610a3bcc0d6d0efc34",
        "adminCapId": "0x259bf75b0d2472ef4dba44b849bba19c373d5f30b3b0d24ffc4ca559524078c2",
        "liquidStatsId": "0x7f8cd8bc2f9dc2b87a7b666affa222e207780d55518bbd4241a04ef2e9349f8b",
    },
    "testnet": {
        "phrase": "",
        "packageId": "0xed67b387dbf8f5a558dfda8fbcaad717a0ada8f67ba8529df38b21b3981e9795",
        "firstVPackageId": "0xc797288b493acb9c18bd9e533568d0d88754ff617ecc6cc184d4a66bce428bdc",
        "liquidStoreId": "0x884e328097377ae266feeda19ed774092dc9035fb82755bfd61cca4dd2c4c366",
        "liquidStatsId": "0xd01418b7822bccd7b642ce28262019fb9eed66844e0db4d2b67c328049b37379",
        "adminCapId": "0x4d692eb0b1b770405a61645ca61a174a163eaef7a7b60c8d5544b24d5698f3af",
    },
};


settings[selectedChain].chain = selectedChain;
if (argv.phrase) {
    settings[selectedChain].phrase = argv.phrase;
}

module.exports = settings[selectedChain];