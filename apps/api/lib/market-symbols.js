// Verified Alpha Vantage exchange aliases for the same canonical listing.
// Keep older provider-qualified inputs valid for existing wallets and clients.
const alphaExchanges = { LON: 'L', DEX: 'DE', FRK: 'F' };
export function canonicalAlphaSymbol(symbol) {
  const suffix = symbol.split('.').at(-1);
  return alphaExchanges[suffix] ? `${symbol.slice(0,-suffix.length)}${alphaExchanges[suffix]}` : symbol;
}
export function alphaSymbol(symbol) {
  const suffix = symbol.split('.').at(-1);
  const exchange = Object.keys(alphaExchanges).find(key => alphaExchanges[key] === suffix);
  return exchange ? `${symbol.slice(0,-suffix.length)}${exchange}` : symbol;
}
