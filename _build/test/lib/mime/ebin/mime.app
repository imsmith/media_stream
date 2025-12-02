{application,mime,
             [{compile_env,[{mime,[extensions],error},
                            {mime,[suffixes],error},
                            {mime,[types],
                                  {ok,#{<<"application/vnd.apple.mpegurl">> =>
                                            [<<"m3u8">>],
                                        <<"audio/x-mpegurl">> =>
                                            [<<"m3u">>]}}}]},
              {optional_applications,[]},
              {applications,[kernel,stdlib,elixir,logger]},
              {description,"A MIME type module for Elixir"},
              {modules,['Elixir.MIME']},
              {registered,[]},
              {vsn,"2.0.7"},
              {env,[]}]}.
