defmodule BaumeisterWeb.Web.ErrorHelpers do
  @moduledoc """
  Conveniences for translating and building error messages.
  """

  use Phoenix.HTML
  use BaumeisterWeb.Web.ButtonHelpers

  @doc """
  Generates tag for inlined form input errors.
  """
  def error_tag(form, field) do
    if error = form.errors[field] do
      content_tag :span, [info_icon(), translate_error(error)], class: "help-block"
    end
  end

  @doc """
  Create the info icon from the glyphicon set.
  """
  def info_icon, do: glyph "info-sign"

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
      Gettext.dngettext(BaumeisterWeb.Web.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(BaumeisterWeb.Web.Gettext, "errors", msg, opts)
    end
  end
end
