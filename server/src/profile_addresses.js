/** Normalize delivery addresses from customer_accounts (production schema). */

function tryParseJson(value) {
  if (value == null) return null;
  if (typeof value === 'object') return value;
  if (typeof value !== 'string') return null;
  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
}

function toAddressEntry(raw, index) {
  if (raw == null) return null;
  if (typeof raw === 'string') {
    const address = raw.trim();
    if (!address) return null;
    return { label: `Address ${index + 1}`, address };
  }
  if (typeof raw === 'object' && !Array.isArray(raw)) {
    const address = String(
      raw.address ?? raw.delivery_address ?? raw.deliveryAddress ?? '',
    ).trim();
    if (!address) return null;
    const label = String(raw.label ?? raw.name ?? `Address ${index + 1}`).trim();
    return { label: label || `Address ${index + 1}`, address };
  }
  return null;
}

/** Primary delivery line (canonical: primary_delivery_address). */
export function primaryDeliveryFromAccountRow(account) {
  const primary = String(account?.primary_delivery_address ?? '').trim();
  const legacy = String(account?.delivery_address ?? '').trim();
  return primary || legacy || null;
}

/**
 * @returns {{ deliveryAddress: string|null, otherDeliveryAddresses: Array<{label:string,address:string}> }}
 */
export function profileAddressesFromAccountRow(account) {
  const primary = primaryDeliveryFromAccountRow(account) ?? '';

  const seen = new Set();
  const other = [];

  const pushOther = (entry) => {
    if (!entry?.address) return;
    const key = entry.address.toLowerCase();
    if (primary && key === primary.toLowerCase()) return;
    if (seen.has(key)) return;
    seen.add(key);
    other.push(entry);
  };

  const otherRaw = tryParseJson(account.other_delivery_addresses);
  if (Array.isArray(otherRaw)) {
    otherRaw.forEach((item, i) => {
      const entry = toAddressEntry(item, i);
      if (entry) pushOther(entry);
    });
  }

  return {
    deliveryAddress: primary || null,
    otherDeliveryAddresses: other,
  };
}
