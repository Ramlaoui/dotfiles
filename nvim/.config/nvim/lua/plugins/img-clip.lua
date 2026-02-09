return {
  {
    "HakonHarnes/img-clip.nvim",
    event = "VeryLazy",
    config = function()
      require("img-clip").setup({
        default = {
          dir_path = "figures",
          extension = "png",
          file_name = "%Y-%m-%d-%H-%M-%S",
          use_absolute_path = false,
          relative_to_current_file = false,
          template = "$FILE_PATH",
          url_encode_path = false,
          relative_template_path = true,
          use_cursor_in_template = true,
          insert_mode_after_paste = true,
          prompt_for_file_name = true,
          show_dir_path_in_prompt = false,
          max_base64_size = 10,
          embed_image_as_base64 = false,
          process_cmd = "",
          copy_images = false,
          download_images = true,
          drag_and_drop = {
            enabled = true,
            insert_mode = false,
          },
        },
        filetypes = {
          markdown = {
            url_encode_path = true,
            template = "![$CURSOR]($FILE_PATH)",
            download_images = false,
          },
          vimwiki = {
            url_encode_path = true,
            template = "![$CURSOR]($FILE_PATH)",
            download_images = false,
          },
          html = {
            template = '<img src="$FILE_PATH" alt="$CURSOR">',
          },
          tex = {
            relative_template_path = false,
            template = [[
        \begin{figure}[h]
          \centering
          \includegraphics[width=0.8\textwidth]{$FILE_PATH}
          \caption{$CURSOR}
          \label{fig:$LABEL}
        \end{figure}
            ]],
          },
          typst = {
            template = [[
        #figure(
          image("$FILE_PATH", width: 80%),
          caption: [$CURSOR],
        ) <fig-$LABEL>
            ]],
          },
          rst = {
            template = [[
        .. image:: $FILE_PATH
           :alt: $CURSOR
           :width: 80%
            ]],
          },
          asciidoc = {
            template = 'image::$FILE_PATH[width=80%, alt="$CURSOR"]',
          },
          org = {
            dir_path = "img",
            template = [=[
        #+BEGIN_FIGURE
        [[file:$FILE_PATH]]
        #+CAPTION: $CURSOR
        #+NAME: fig:$LABEL
        #+END_FIGURE
            ]=],
          },
        },
        files = {},
        dirs = {},
        custom = {},
      })
    end,
  },
}

