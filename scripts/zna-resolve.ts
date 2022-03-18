import * as zns from "@zero-tech/zns-sdk";

const someZna = "wilder.wheels";
const zNAAsNumber = zns.domains.domainNameToId(someZna);
// wilder.wheels is 0x7445164548beaf364109b55d8948f056d6e4f1fd26aff998c9156b0b05f1641f
console.log(`${someZna} is ${zNAAsNumber}`);
