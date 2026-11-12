module Admin
  # Fork-only: actions on single entries of the Telegram autoposting queue.
  class SocialAutopostItemsController < Admin::ApplicationController
    layout "admin"

    before_action :set_item

    def update
      @item.update!(params.require(:social_autopost_item).permit(:custom_message, :kind))
      redirect_to admin_social_autoposts_path(anchor: "item-#{@item.id}"), flash: { success: "Message updated." }
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_social_autoposts_path, flash: { danger: e.message }
    end

    def post_now
      unless SocialAutopost.configured?
        return redirect_to(admin_social_autoposts_path, flash: { danger: "Set the bot token and channel first." })
      end
      unless @item.queued?
        return redirect_to(admin_social_autoposts_path, flash: { danger: "This article is not in the queue." })
      end

      @item.update!(post_after: Time.current)
      SocialAutopost::PostItemWorker.perform_async(@item.id)
      redirect_to admin_social_autoposts_path, flash: { success: "Sending “#{@item.article.title}” now." }
    end

    def move_top
      @item.update!(priority: SocialAutopost::Enqueuer.top_priority)
      redirect_to admin_social_autoposts_path, flash: { success: "Moved to the top of the queue." }
    end

    def skip
      @item.update!(status: "skipped", skip_reason: "admin", post_after: nil) if @item.queued?
      redirect_to admin_social_autoposts_path, flash: { success: "Skipped. It won't be posted automatically." }
    end

    def requeue
      if @item.posted? || @item.sending?
        return redirect_to(admin_social_autoposts_path, flash: { danger: "Already posted." })
      end

      @item.update!(status: "queued", skip_reason: nil, attempts: 0, last_error: nil, post_after: nil)
      redirect_to admin_social_autoposts_path, flash: { success: "Back in the queue." }
    end

    # Removing an entry lets the rating rules pick the article up again later;
    # "skip" keeps it out for good.
    def destroy
      @item.destroy! unless @item.sending?
      redirect_to admin_social_autoposts_path, flash: { success: "Removed from the queue." }
    end

    protected

    def authorization_resource
      SocialAutopostItem
    end

    private

    def set_item
      @item = SocialAutopostItem.find(params[:id])
    end
  end
end
