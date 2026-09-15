class CustomMailer < ApplicationMailer
  include Rails.application.routes.url_helpers

  default from: -> { email_from(I18n.t("mailers.custom_mailer.from")) }

  has_history extra: lambda {
    {
      email_id: params[:email_id]
    }
  }, only: :custom_email


  def custom_email
    @user = params[:user]
    @content = Email.replace_merge_tags(params[:content], @user)
    @subject = Email.replace_merge_tags(params[:subject], @user)
    @unsubscribe = generate_unsubscribe_token(@user.id, :email_newsletter)
    add_unsubscribe_headers(@unsubscribe)
    email = params[:email]
    @from_topic = resolve_from_topic(email)
    setup_custom_email_footer(email)

    # set sendgrid category in the header using smtp api
    # https://docs.sendgrid.com/for-developers/sending-email/building-an-x-smtpapi-header
    if ForemInstance.sendgrid_enabled?
      smtpapi_header = {
        category: "#{params[:type_of] || 'Custom'} Email",
        unique_args: {
          mailing_id: "email-instance-#{params[:email_id]}"
        }
      }.to_json
    
      headers["X-SMTPAPI"] = smtpapi_header
    end

    mail(to: @user.email, subject: @subject, from: email_from(@from_topic))
  end

  private

  def resolve_from_topic(email)
    if !params[:from_name].nil?
      params[:from_name]
    elsif email.present?
      email.default_from_name_based_on_type
    elsif params[:email_id].present?
      Email.find_by(id: params[:email_id])&.default_from_name_based_on_type
    end
  end

  def setup_custom_email_footer(email)
    if params.key?(:override_footer_html)
      @override_footer_html = params[:override_footer_html]
      @custom_email_footer = params[:custom_email_footer]
    elsif email.present?
      if email.override_footer_html?
        @override_footer_html = true
        @custom_email_footer = email.custom_footer_html
      end
    elsif params[:email_id].present? && params[:from_name].nil?
      record = Email.find_by(id: params[:email_id])
      if record&.override_footer_html?
        @override_footer_html = true
        @custom_email_footer = record.custom_footer_html
      end
    end

    return unless @override_footer_html && @custom_email_footer.present?

    @custom_email_footer = Email.replace_merge_tags(@custom_email_footer, @user)
  end
end
