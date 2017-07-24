defmodule BaumeisterWeb.Web.ButtonHelpers do
  @moduledoc """
  Conveniences for defining Buttons including Icons.
  """

  use Phoenix.HTML

  @doc false
  # Using this module means importing all functions.
  defmacro __using__(_) do
    quote do
      import BaumeisterWeb.Web.ButtonHelpers
    end
  end

  def edit_label, do: ["Edit ", glyph "pencil"]
  def delete_label, do: ["Delete ", glyph "trash"]
  def overview_label, do: ["Overview ", glyph "th-list"]
  def new_label(name \\ "Project"), do: ["New " <> name <> " ", glyph "plus"]

  def checkbox_btn(true), do: glyph "check"
  def checkbox_btn(false), do: glyph "unchecked"

  @doc """
  Creates a `span` tag with a glyphicon. Only the postfix of the glyphicon
  name is required.
  """
  def glyph(icon_postfix), do:
    content_tag :span, "", class:  "glyphicon glyphicon-#{icon_postfix}"

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

end
