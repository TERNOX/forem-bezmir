require "rails_helper"

RSpec.describe Articles::ResavePublishedWorker do
  describe "#perform" do
    it "resaves each published article" do
      relation = instance_double(ActiveRecord::Relation)
      article = instance_double(Article)

      allow(Article).to receive(:published).and_return(relation)
      allow(relation).to receive(:find_each).and_yield(article)
      allow(article).to receive(:save)

      described_class.new.perform

      expect(Article).to have_received(:published)
      expect(relation).to have_received(:find_each)
      expect(article).to have_received(:save)
    end
  end
end
