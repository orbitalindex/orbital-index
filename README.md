# Hydejack Starter Kit

A quicker, cleaner way to get started blogging with [Hydejack](https://hydejack.com/).

## Quick Start
### Running locally
1. Clone repository (git users), or [download] and unzip.
2. Open terminal, `cd` into root directory (where `_config.yml` is located)
3. `bundle install` [^1]
4. `bundle exec jekyll serve`
5. Open <http://localhost:4000/hy-starter-kit/>

### GitHub Pages
1. Fork this repository.
2. Go to **Settings**, rename repository to `<your github username>.github.io` (without the `<` `>`)
3. Edit `_config.yml` (you can do this directly on GitHub)
    1. Change `url` to `https://<your github username>.github.io` (without the `<` `>`)
    2. Change `baseurl` to `''` (empty string)
    3. **Commit changes**.
4. Go to **Settings** again, look for **GitHub Pages**, set **Source** to **master branch**.
5. Click **Save** and wait for GitHub to set up your new blag.

# Updating the archive automatically

1. Run `bin/process.rb`.
2. `git add -p`
3. `git commit -m "Issue ____"`
4. `git push`

# Updating the archive manually with a new file

1. Place the new archive html file in `archive/_posts/` with a header of:
    ```
    ---
    layout: page
    title: Issue No. N
    ---
    ```
2. Run `./bin/filter.rb`.
3. `git add -p`
4. `git commit -m "Issue ____"`
5. `git push`

# Updating the supporters page

1. Run `./bin/update_supporters.rb`.
2. `git add -p`
3. `git commit -m "Updated supporters"`
4. `git push`

## What's next?
* Open files and read the comments
* Read the [docs](https://hydejack.com/docs/)
* Buy the [PRO version](https://hydejack.com/download/) to get the project and resume layout, newsletter subscription box, custom forms, and more.

[^1]: Requires Bundler. Install with `gem install bundler`.

[download]: https://github.com/qwtel/hy-starter-kit/archive/master.zip
