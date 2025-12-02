defmodule MediaStream.Media.ListeningHistory do
  use Ecto.Schema
  import Ecto.Changeset

  schema "listening_history" do
    field :device_id, :string
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :duration_listened_seconds, :integer, default: 0
    belongs_to :audio_file, MediaStream.Media.AudioFile

    timestamps()
  end

  @doc false
  def changeset(listening_history, attrs) do
    listening_history
    |> cast(attrs, [
      :audio_file_id,
      :device_id,
      :started_at,
      :completed_at,
      :duration_listened_seconds
    ])
    |> validate_required([:audio_file_id, :device_id, :started_at])
  end
end
