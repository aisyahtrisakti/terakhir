## Generating an XML sitemap

Here is a script which generates a valid XML sitemap, which Google (and others) will use to index your site:

```
#!/bin/bash

# generate an XML sitemap for this site

# script adapted from: http://www.lostsaloon.com/technology/how-to-create-an-xml-sitemap-using-wget-and-shell-script/

. .site_config

sitedomain=https://sc0ttj.github.io/mdsh/

mv sitemap.xml sitemap_prev.xml

echo "Generating sitemap.xml, please wait.."

wget --spider --recursive --level=inf --no-verbose --output-file=linklist.txt "$sitedomain"
grep -i URL linklist.txt | awk -F 'URL:' '
{print $2}' | awk '{$1=$1};1' | awk '{print $1}' | sort -u | sed '/^$/d' > sortedurls.txt

header='&lt;?xml version="1.0" encoding="UTF-8"?&gt;&lt;urlset
      xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9
            http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd"&gt;'

echo "$header" > sitemap.xml

while read p; do
  case "$p" in
  */ | *.html | *.htm)
    echo '&lt;url&gt;&lt;loc&gt;'$p'&lt;/loc&gt;&lt;/url&gt;' >> sitemap.xml
    ;;
  *)
    ;;
 esac
done < sortedurls.txt

echo "&lt;/urlset&gt;" >> sitemap.xml

rm linklist.txt sortedurls.txt &>/dev/null

[ ! -f sitemap.xml ] && exit 1

rm sitemap_prev.xml

echo "Publishing sitemap.."
echo
git add sitemap.xml
git commit -m 'Updated sitemap'
git push origin gh-pages

exit 0
```