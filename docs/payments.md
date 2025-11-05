# Payments configuration

Forem now supports selecting a payment gateway on a per-instance basis. Admins can
choose between Stripe and Monobank from the **Admin > Configuration > Monetization**
section.

## Selecting a provider

1. Visit `/admin/config` as a super admin and open the **Monetization** panel.
2. Use the *Payment provider* select box to choose either **Stripe** or **Monobank**.
3. Enter the credentials for the selected provider:
   - **Stripe** requires the secret API key and publishable key.
   - **Monobank** requires the API key, publishable key, API base URL, and webhook secret.
4. Save the settings. The UI automatically hides non-relevant fields when the provider
   changes.

## Monobank specifics

When Monobank is enabled:

- Administrators must also configure the `/monobank/token` endpoint secret (API key)
  and webhook secret so Forem can validate callbacks.
- Members add or update cards through the billing settings screen using a tokenization
  flow powered by `/monobank/token`. Card forms now live in `app/javascript/settings/monobank`
  and `app/javascript/credits/monobankForm.js`.
- Credit purchases use the same tokenization endpoint. The client-side logic lives in
  `app/javascript/packs/credits/monobankCheckout.js` and ensures the existing pricing
  UX still works.

## Testing

- `spec/requests/monobank_tokens_spec.rb` covers the token endpoint contract.
- `spec/system/settings/admin_configures_payment_provider_spec.rb` exercises the
  admin experience and verifies the provider-specific fields toggle as expected.
