import dev.oreslang.compiler.IncrementalCompiler;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public final class ImportGraphCheck {
    private ImportGraphCheck() {}

    public static void main(String[] args) throws Exception {
        if (args.length != 1) {
            throw new IllegalArgumentException("usage: ImportGraphCheck <source-directory>");
        }

        Path root = Path.of(args[0]).toAbsolutePath().normalize();
        if (!Files.isDirectory(root)) {
            throw new IllegalArgumentException("not a directory: " + root);
        }

        List<Path> paths = new ArrayList<>();
        try (var stream = Files.walk(root)) {
            stream.filter(Files::isRegularFile)
                    .filter(path -> path.getFileName().toString().endsWith(".ores"))
                    .sorted()
                    .forEach(paths::add);
        }

        Map<String, String> sources = new LinkedHashMap<>();
        for (Path path : paths) {
            String unit = root.relativize(path).toString().replace('\\', '/');
            sources.put(unit, Files.readString(path));
        }

        new IncrementalCompiler().compile(sources);
        System.out.println("import-graph-ok:" + sources.size());
    }
}
