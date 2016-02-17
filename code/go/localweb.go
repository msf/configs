package main

import (
    "encoding/json"
    "fmt"
    "html/template"
    "log"
    "net/http"
    "net/url"
    "time"
)

func main() {
    register("/hello", handleHello)
    register("/search", handleSearch)
    log.Fatal(http.ListenAndServe("localhost:7777", nil))
}


func register(path string, handler func(http.ResponseWriter, *http.Request)) {
    http.HandleFunc(path, handler)
    fmt.Println("serving on http://localhost:7777" + path)
}


func handleHello(w http.ResponseWriter, req *http.Request) {
    log.Println("serving", req.URL)
    go fmt.Fprintln(w, "Hello, wtf!")
}

func handleSearch(w http.ResponseWriter, req *http.Request) {
    log.Println("serving", req.URL)

    // Check the search query.
    query := req.FormValue("q")
    if query == "" {
        http.Error(w, `missing "q" URL parameter`, http.StatusBadRequest)
        return
    }
    // Run the Google search.
    start := time.Now()
    results, err := Search(query)
    elapsed := time.Since(start)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }

    // Render the results.
    type templateData struct {
        Results []Result
        Elapsed time.Duration
    }
    err := resultsTemplate.Execute(w, templateData{
        Results: results,
        Elapsed: elapsed,
    })
    if err != nil {
        log.Print(err)
        return
    }

    var jsonResponse struct {
        ResponseData struct {
            Results []struct {
                TitleNoFormatting, URL string
            }
        }
    }
    if err := json.NewDecoder(resp.Body).Decode(&jsonResponse); err != nil {
        return nil, err
    }

    // Extract the Results from jsonResponse and return them.
    var results []Result
    for _, r := range jsonResponse.ResponseData.Results {
        results = append(results, Result{Title: r.TitleNoFormatting, URL: r.URL})
    }
    return results, nil
}
}

// A Result contains the title and URL of a search result.
type Result struct {
    Title, URL string
}

var resultsTemplate = template.Must(template.New("results").Parse(`
<html>
<head/>
<body>
  <ol>
  {{range .Results}}
    <li>{{.Title}} - <a href="{{.URL}}">{{.URL}}</a></li>
  {{end}}
  </ol>
  <p>{{len .Results}} results in {{.Elapsed}}</p>
</body>
</html>
`))
}


func Search(query string) ([]Result, error) {
    // Prepare the Google Search API request.
    u, err := url.Parse("https://ajax.googleapis.com/ajax/services/search/web?v=1.0")
    if err != nil {
        return nil, err
    }
    q := u.Query()
    q.Set("q", query)
    u.RawQuery = q.Encode()

    // Issue the HTTP request and handle the response.
    resp, err := http.Get(u.String())
    if err != nil {
        return nil, err
    }
    defer resp.Body.Close()
}



