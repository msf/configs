import java.io.BufferedInputStream;
import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.net.URL;
import java.net.URLConnection;
import java.util.Scanner;
import java.util.regex.Pattern;


public final class ReadAdjacencyList {

    private Scanner scanner;

    // assume Unicode UTF-8 encoding
    private static final String charsetName = "UTF-8";

    // assume language = English, country = US for consistency with System.out.
    private static final java.util.Locale usLocale = 
        new java.util.Locale("en", "US");

    // the default token separator; we maintain the invariant that this value 
    // is held by the scanner's delimiter between calls
    private static final Pattern WHITESPACE_PATTERN
        = Pattern.compile("\\p{javaWhitespace}+");

    // makes whitespace characters significant 
    private static final Pattern EMPTY_PATTERN
        = Pattern.compile("");

    int vertexCount = 0;
    Graph graph;


    public ReadAdjacencyList(String s) {
        try {
            // first try to read file from local file system
            File file = new File(s);
            if (file.exists()) {
                scanner = new Scanner(file, charsetName);
                scanner.useLocale(usLocale);
                return;
            }
        }
        catch (IOException ioe) {
            System.err.println("Could not open " + s);
        }

        ArrayList<String> lines = new ArrayList<String>();
        while(scanner.hasNextLine()) {
            lines.add(scanner.readLine());
            vertexCount++;
        }

        int basePoint = "A".codePointAt(0);
        graph = new Graph(vertexCount);
        for(String line: lines) {
            int v = line.codePointAt(0) - basePoint;
            String edges = line.substring(1).split(WHITESPACE_PATTERN);
            for(String e: edges) {
                int w = e.codePointAt(0) - basePoint;
                if(w > 0)
                    graph.addEdge(v,w);
            }
        }
    }

   /**
     * Read and return the next line.
     */
    public String readLine() {
        String line;
        try                 { line = scanner.nextLine(); }
        catch (Exception e) { line = null;               }
        return line;
    }

    /**
     * Read and return the next character.
     */
    public char readChar() {
        scanner.useDelimiter(EMPTY_PATTERN);
        String ch = scanner.next();
        assert (ch.length() == 1) : "Internal (Std)In.readChar() error!"
            + " Please contact the authors.";
        scanner.useDelimiter(WHITESPACE_PATTERN);
        return ch.charAt(0);
    }  

    public String printGraph() {

    }

    public static void main(String[] args) {
        ReadAdjacencyList ral = new ReadAdjacencyList(args[1]);

        ral.printGraph();
    }

}
