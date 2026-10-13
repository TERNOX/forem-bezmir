require "rails_helper"
require "swagger_helper"

# rubocop:disable RSpec/EmptyExampleGroup

describe "GET /tags" do
  before { create_list(:tag, 3) }

  path "/api/tags" do
    get "Tags" do
      tags "tags"
      security []
      description "This endpoint allows the client to retrieve a list of tags that can be used to tag articles.

It will return tags ordered by popularity.

It supports pagination, each page will contain 10 tags by default."
      operationId "getTags"
      produces "application/json"
      parameter "$ref": "#/components/parameters/pageParam"
      parameter "$ref": "#/components/parameters/perPageParam10to1000"

      response "200", "A List of all tags" do
        schema  type: :array,
                items: { "$ref": "#/components/schemas/Tag" }
        add_examples

        run_test!
      end
    end
  end

  path "/api/tags/supported" do
    get "Supported tags" do
      tags "tags"
      security []
      description "Retrieve every tag supported on the platform (or current subforem), ordered by popularity.

### Integration Tips:
- Bypasses authentication (can be accessed publicly).
- Not paginated: returns the complete list of supported tags in a single response.
- Edge cached; changes to a tag's supported status are purged from the cache automatically."
      operationId "getSupportedTags"
      produces "application/json"

      response "200", "A List of all supported tags" do
        schema  type: :array,
                items: { "$ref": "#/components/schemas/Tag" }
        add_examples

        run_test!
      end
    end
  end
end

# rubocop:enable RSpec/EmptyExampleGroup
