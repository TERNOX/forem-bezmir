require "rails_helper"

RSpec.describe "I18n pluralization" do
  it "uses the Ukrainian one/few/many forms" do
    expect(I18n.t("core.counted_user", count: 1, locale: :uk)).to eq("1 людина")
    expect(I18n.t("core.counted_user", count: 3, locale: :uk)).to eq("3 людини")
    expect(I18n.t("core.counted_user", count: 5, locale: :uk)).to eq("5 людей")
    expect(I18n.t("core.counted_user", count: 11, locale: :uk)).to eq("11 людей")
    expect(I18n.t("core.counted_user", count: 21, locale: :uk)).to eq("21 людина")
    expect(I18n.t("core.counted_user", count: 22, locale: :uk)).to eq("22 людини")
  end

  it "keeps the number in Ukrainian one forms that also cover 21, 31, ..." do
    expect(I18n.t("datetime.expires_in.x_days", count: 21, locale: :uk)).to eq("Мине 21 день")
  end

  it "falls back to the other form when a Ukrainian form is missing" do
    expect(I18n.backend.send(:pluralize, :uk, { one: "one", other: "other" }, 5)).to eq("other")
  end

  it "keeps English on one/other" do
    expect(I18n.t("core.counted_user", count: 1, locale: :en)).to eq("1 person")
    expect(I18n.t("core.counted_user", count: 3, locale: :en)).to eq("3 people")
  end
end
