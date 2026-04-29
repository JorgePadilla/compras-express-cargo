# Issuing company info for the Warehouse Receipt (Miami LLC).
# Per spec `warehouse_receipt_fields.md` §8: this is a single constant, not a
# DB table. The HND-side `Empresa` (San Pedro Sula) is the operating company;
# this LLC is the US entity that physically receives packages and issues the
# WR. Update via this file or env vars in deploy.
Rails.application.config.x.warehouse_receipt = ActiveSupport::OrderedOptions.new.merge!(
  issuing_company: ActiveSupport::OrderedOptions.new.merge!(
    name: "COMPRAS EXPRESS LOGISTICS LLC",
    street: "8109 NW 60th STREET",
    city: "Miami",
    state: "Florida",
    postal_code: "33195-3415",
    country: "USA",
    phone: "+1 305-848-0990",
    website: "https://www.comprasexpresshn.com"
  ),
  terms_version: "2026-01"
)
