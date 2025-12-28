class CatalogItemsController < ApplicationController
  before_action :authenticate_user!, only: %i[new create edit update]
  before_action :ensure_catalog_available!
  before_action :set_catalog_item, only: %i[show edit update]
  before_action :authorize_catalog_item_edit!, only: %i[edit update]

  def index
    @display_mode = params[:view].presence_in(%w[grid list]) || "list"
    @catalog_items = CatalogItem.published
      .from_subforem
      .includes(:user, :subforem, :tags, catalog_field_values: :catalog_field_definition)
      .order(created_at: :desc)

    if params[:tag].present?
      @catalog_items = @catalog_items.tagged_with(params[:tag])
    end
    if params[:q].present?
      @catalog_items = @catalog_items.where("catalog_items.title ILIKE :q OR catalog_items.description ILIKE :q",
                                            q: "%#{params[:q]}%")
    end

    @catalog_items = @catalog_items.page(params[:page]).per(24)
    @field_definitions = CatalogFieldDefinition.from_subforem.ordered
  end

  def show
    @field_definitions = CatalogFieldDefinition.from_subforem.ordered
  end

  def new
    @catalog_item = CatalogItem.new
    build_field_values
  end

  def create
    @catalog_item = current_user.catalog_items.new(catalog_item_params)
    @catalog_item.subforem_id = RequestStore.store[:subforem_id]

    if @catalog_item.save
      redirect_to catalog_item_path(@catalog_item), notice: t("views.catalog_items.messages.created")
    else
      @field_definitions = CatalogFieldDefinition.from_subforem.ordered
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    build_field_values
  end

  def update
    if @catalog_item.update(catalog_item_params)
      redirect_to catalog_item_path(@catalog_item), notice: t("views.catalog_items.messages.updated")
    else
      build_field_values
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def catalog_item_params
    params.require(:catalog_item).permit(
      :title,
      :description,
      :cover_image,
      catalog_field_values_attributes: %i[id catalog_field_definition_id value_string file]
    )
  end

  def set_catalog_item
    @catalog_item = CatalogItem.from_subforem.find(params[:id])
  end

  def build_field_values
    @field_definitions = CatalogFieldDefinition.from_subforem.ordered
    @field_definitions.each do |definition|
      next if @catalog_item.catalog_field_values.any? { |value| value.catalog_field_definition_id == definition.id }

      @catalog_item.catalog_field_values.build(catalog_field_definition: definition)
    end
  end

  def ensure_catalog_available!
    return if Settings::UserExperience.catalog_enabled(subforem_id: RequestStore.store[:subforem_id])

    not_found
  end

  def authorize_catalog_item_edit!
    return if current_user&.any_admin? || @catalog_item.user_id == current_user&.id

    head :forbidden
  end
end
