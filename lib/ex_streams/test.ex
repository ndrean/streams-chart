defmodule Test do
  def input() do
    Req.get!("https://httpbin.org/stream/5",
      into: fn {:data, chunk}, acc ->
        # Split chunk by newlines and process each JSON object
        chunk
        |> String.split("\n", trim: true)
        |> Enum.each(fn line ->
          if String.trim(line) != "" do
            res = Jason.decode!(line)
            dbg(res)
          end
        end)

        {:cont, acc}
      end
    )
  end
end
