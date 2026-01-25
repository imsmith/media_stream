defmodule MediaStream.Media.PlaybackState do
  use Ecto.Schema
  import Ecto.Changeset

  schema "playback_states" do
    field :device_id, :string
    field :position_seconds, :float, default: 0.0
    field :queue_json, :string
    field :playing, :boolean, default: false
    field :active_player_id, :string
    belongs_to :current_file, MediaStream.Media.AudioFile

    timestamps()
  end

  @doc false
  def changeset(playback_state, attrs) do
    playback_state
    |> cast(attrs, [:device_id, :current_file_id, :position_seconds, :queue_json, :playing, :active_player_id])
    |> validate_required([:device_id])
    |> unique_constraint(:device_id)
  end
end
