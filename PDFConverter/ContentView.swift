//
//  ContentView.swift
//  PDFConverter
//
//  Created by Maurice Nowotni on 31.07.24.
//

import SwiftUI

struct ContentView: View {
    @State var filename = "name"
    @State var fileURL: URL?
    
    @State private var pdfs: [Pdf] = []
    @State private var downloadMessage: String = ""

    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("PDF Converter").padding()
            Text(filename)
            Button("Browse File") {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                if panel.runModal() == .OK {
                    self.fileURL = panel.url
                    self.filename = panel.url?.lastPathComponent ?? "<none>"
                }
            }.padding()
            Button("Convert to PDF") {
                convertToPDF()
            }.padding()
            List(pdfs, id: \.id) { pdf in
                HStack {
                    Text(pdf.filename)
                    Image(systemName: "square.and.arrow.down.fill").imageScale(.small).onTapGesture {
                        downloadPDF(id: pdf.id)
                    }
                }
            }.onAppear(perform: {
                fetchPDFs()
            })
            Text(downloadMessage)
                .foregroundColor(.red)
                .padding()
        }
        .padding()
    }

    func convertToPDF() {
        guard let url = fileURL else { return }
        // Determine file type and handle accordingly
        if url.pathExtension.lowercased() == "jpg" || url.pathExtension.lowercased() == "png" {
            createPDF(from: url)
        } else {
            filename = "Path extension not supported"
        }
    }

    func createPDF(from imageURL: URL) {
        guard let image = NSImage(contentsOf: imageURL) else { return }
        
        let pdfData = NSMutableData()
        let consumer = CGDataConsumer(data: pdfData as CFMutableData)!
        var mediaBox = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)!
        context.beginPDFPage(nil)
        
        let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        context.draw(cgImage!, in: mediaBox)
        
        context.endPDFPage()
        context.closePDF()
        // Save the PDF to the desktop
        let filenameWithoutPathExtension = imageURL.deletingPathExtension().lastPathComponent
        let saveURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/\(filenameWithoutPathExtension).pdf")
        pdfData.write(to: saveURL, atomically: true)
        print("PDF Data size: \(pdfData.length) bytes")
        print("PDF saved to: \(saveURL)")
        
        uploadPDF(fileURL: saveURL)
    }

    func uploadPDF(fileURL: URL) {
        guard let url = URL(string: "http://localhost:8080/pdf") else {
            print("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let data = createBody(filePathKey: "file", fileURL: fileURL, boundary: boundary)

        URLSession.shared.uploadTask(with: request, from: data) { responseData, response, error in
            if let error = error {
                print("Upload error: \(error.localizedDescription)")
                return
            }
            guard let responseData = responseData else {
                print("No response data")
                return
            }
            if let responseString = String(data: responseData, encoding: .utf8) {
                print("Response: \(responseString)")
            }
            
            fetchPDFs()
        }.resume()
    }

    func createBody(filePathKey: String, fileURL: URL, boundary: String) -> Data {
        var body = Data()
        
        let filename = fileURL.lastPathComponent
        let mimetype = "application/pdf"
        let data = try! Data(contentsOf: fileURL)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(filePathKey)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimetype)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }

    func fetchPDFs() {
        guard let url = URL(string: "http://localhost:8080/pdf") else {
            print("Invalid URL")
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                do {
                    let decodedData = try JSONDecoder().decode([Pdf].self, from: data)
                    DispatchQueue.main.async {
                        self.pdfs = decodedData
                    }
                } catch {
                    print("Error decoding data: \(error)")
                }
            } else if let error = error {
                print("HTTP Request Failed \(error)")
            }
        }.resume()
    }
    
    func downloadPDF(id: Int) {
        guard let url = URL(string: "http://localhost:8080/pdf/\(id)") else {
            print("Invalid URL")
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                do {
                    let documentsURL = try FileManager.default.url(
                        for: .downloadsDirectory,
                        in: .userDomainMask,
                        appropriateFor: nil,
                        create: false
                    )
                    let fileName = response?.suggestedFilename ?? "downloaded.pdf"
                    let fileURL = documentsURL.appendingPathComponent(fileName)
                    try data.write(to: fileURL)
                    DispatchQueue.main.async {
                        self.downloadMessage = "PDF downloaded to: \(fileURL.path)"
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.downloadMessage = "Failed to save PDF: \(error.localizedDescription)"
                    }
                }
            } else if let error = error {
                DispatchQueue.main.async {
                    self.downloadMessage = "Download error: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
}

struct Pdf: Codable, Identifiable {
    let id: Int
    let filename: String
}

#Preview {
    ContentView()
}
