defmodule BaumeisterWeb.ErrorHelpers do
  @moduledoc """
  Conveniences for translating and building error messages.
  """

  use Phoenix.HTML

  @doc """
  Generates tag for inlined form input errors.
  """
  def error_tag(form, field) do
    if error = form.errors[field] do
      content_tag :span, translate_error(error), class: "help-block"
    end
  end

  @doc """
  Creates the opening div tag for form group containing the `field`
  of the `form`. It takes the `error` of the field into account to
  use the correct classes to show errors in the field content.
  """
  def form_group(form, field) do
    if form.errors[field] == nil do
      tag :div, class: "form-group"
    else
      tag :div, class: "form-group has-error"
    end
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # Because error messages were defined within Ecto, we must
    # call the Gettext module passing our Gettext backend. We
    # also use the "errors" domain as translations are placed
    # in the errors.po file.
    # Ecto will pass the :count keyword if the error message is
    # meant to be pluralized.
    # On your own code and templates, depending on whether you
    # need the message to be pluralized or not, this could be
    # written simply as:
    #
    #     dngettext "errors", "1 file", "%{count} files", count
    #     dgettext "errors", "is invalid"
    #
    if count = opts[:count] do
      Gettext.dngettext(BaumeisterWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(BaumeisterWeb.Gettext, "errors", msg, opts)
    end
  end
end
