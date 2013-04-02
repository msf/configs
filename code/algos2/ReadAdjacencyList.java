import java.util.ArrayList;
import java.util.HashMap;

public final class ReadAdjacencyList {

	HashMap<String,Integer> symbolTable = new HashMap<String, Integer>();
	String[] reverseSymbolTable;
	In input;
	int vertexCount = 0;
	Graph graph;

	public ReadAdjacencyList(String s) {
		
		input = new In(s);
		reverseSymbolTable = new String[256];
		
		ArrayList<String> lines = new ArrayList<String>();
		while (input.hasNextLine()) {
			String line = input.readLine();
			lines.add(line);
			String letter = line.substring(0, 1).toLowerCase();
			setGetEdge(letter);
		}

		StdOut.printf("Graph c/ vertices:%d\n",vertexCount);
		graph = new Graph(vertexCount);
		vertexCount = 0;
		for (String line : lines) {
			String letter = line.substring(0, 1).toLowerCase();
			int v = setGetEdge(letter);
			String[] edges = line.substring(3).split(" ");
			for (String e : edges) {
				int w = setGetEdge(e);
				StdOut.printf("edge:%s-%s : %d-%d\n", letter,e,v,w);
				if(!graph.hasEdge(v, w))
					graph.addEdge(v, w);
			}
		}
	}


	private Integer setGetEdge(String edge) {
		String e = edge.toLowerCase();
		if(!symbolTable.containsKey(e))
			symbolTable.put(e, vertexCount++);
		int v = symbolTable.get(e);
		reverseSymbolTable[v] = e;
		return v;
	}
	
	public String printGraph() {

		StringBuilder sb = new StringBuilder();
		sb.append(graph.toString());
		sb.append("\n");
		for(int i = 0; i < graph.V(); i++) {
			sb.append(reverseSymbolTable[i]);
			sb.append(": ");
			for(int adj : graph.adj(i)) {
				sb.append(reverseSymbolTable[adj]);
				sb.append(" ");
			}
			sb.append("\n");
		}
		return sb.toString();
	}

	public static void main(String[] args) {
		ReadAdjacencyList ral = new ReadAdjacencyList(args[0]);
		
		StdOut.print(ral.printGraph());
	}

}

