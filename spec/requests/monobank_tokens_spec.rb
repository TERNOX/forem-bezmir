require "rails_helper"

RSpec.describe "MonobankTokens" do
  describe "POST /monobank/token" do
    context "when authenticated" do
      let(:user) { create(:user) }

      before { sign_in user }

      context "when Monobank provider is enabled" do
        let(:gateway) { instance_double(Payments::MonobankGateway) }

        before do
          allow(Settings::General).to receive(:payment_provider).and_return("monobank")
          allow(Payments::Gateway).to receive(:build).with(provider: :monobank).and_return(gateway)
        end

        it "returns a token" do
          allow(gateway).to receive(:tokenize_card).and_return("tok_123")

          post monobank_token_path, params: { card: { number: "4242", exp_month: "12", exp_year: "2029", cvv: "123" } }

          expect(response).to have_http_status(:ok)
          expect(response.parsed_body).to include("token" => "tok_123")
        end

        it "returns an error when tokenization fails" do
          allow(gateway).to receive(:tokenize_card).and_raise(Payments::PaymentsError, "nope")

          post monobank_token_path, params: { card: { number: "4242", exp_month: "12", exp_year: "2029", cvv: "123" } }

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.parsed_body).to include("error" => "nope")
        end

        it "returns an error when card params are missing" do
          allow(gateway).to receive(:tokenize_card)

          post monobank_token_path

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.parsed_body["error"]).to be_present
        end
      end

      it "returns 404 when Monobank is not the active provider" do
        allow(Settings::General).to receive(:payment_provider).and_return("stripe")

        post monobank_token_path, params: { card: { number: "4242", exp_month: "12", exp_year: "2029", cvv: "123" } }

        expect(response).to have_http_status(:not_found)
      end
    end

    it "requires authentication" do
      post monobank_token_path, params: { card: { number: "4242", exp_month: "12", exp_year: "2029", cvv: "123" } }

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
