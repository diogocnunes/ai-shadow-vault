---
name: syncfusion-document-editor
description: Expert guidance for Syncfusion Document Editor (Word Processor Component) integration. Use when implementing Word-like document editing, working with .docx files, configuring document editor toolbars, handling document operations (open, save, export), implementing track changes, comments, and collaboration features, managing document formatting, working with tables and styles, integrating with backend APIs, or troubleshooting Document Editor issues. Covers React, Angular, Vue, and JavaScript implementations.
---

# Syncfusion Document Editor Expert

Comprehensive guidance for integrating Syncfusion's Document Editor Component - the enterprise-grade Word processor for web applications.

## Core Responsibilities

### 1. Document Editor Integration
- Initialize and configure DocumentEditorContainer
- Set up server-side dependencies (Web API)
- Configure toolbar and properties pane
- Implement document lifecycle management
- Handle .docx, .doc, .rtf, .txt, and .sfdt formats

### 2. Document Operations
- Open documents from various sources (file, URL, base64)
- Save documents in multiple formats
- Export to PDF, Word, SFDT
- Import from Word/HTML/text
- Print documents with customization

### 3. Collaboration Features
- Track changes and revision history
- Comments and annotations
- User permissions and restrictions
- Real-time collaboration setup
- Document locking mechanisms

### 4. Advanced Features
- Custom toolbar items and actions
- Spell checker integration
- Find and replace operations
- Mail merge functionality
- Form fields and content controls
- Bookmarks and hyperlinks

## Installation & Setup

### React Installation
```bash
# Core package
npm install @syncfusion/ej2-react-documenteditor

# Required dependencies
npm install @syncfusion/ej2-base @syncfusion/ej2-data @syncfusion/ej2-buttons
npm install @syncfusion/ej2-splitbuttons @syncfusion/ej2-dropdowns
npm install @syncfusion/ej2-inputs @syncfusion/ej2-popups @syncfusion/ej2-lists
npm install @syncfusion/ej2-navigations @syncfusion/ej2-calendars
```

### Angular Installation
```bash
ng add @syncfusion/ej2-angular-documenteditor
```

### Server-Side Setup (Required for Import/Export)
```bash
# .NET Core Web API
dotnet add package Syncfusion.EJ2.DocumentEditor.AspNet.Core.Net6

# Or Node.js (if using node backend)
npm install @syncfusion/ej2-documenteditor-server
```

## Document Editor Architecture

### Component Types

**1. DocumentEditorContainer (Recommended)**
- Full-featured with toolbar and properties pane
- Built-in UI for all features
- Best for most applications

**2. DocumentEditor (Core)**
- Programmatic access only
- Custom UI implementation required
- Maximum flexibility

### Essential Imports
```javascript
import { 
  DocumentEditorContainerComponent,
  Toolbar
} from '@syncfusion/ej2-react-documenteditor';

// Register license (required for production)
import { registerLicense } from '@syncfusion/ej2-base';
registerLicense('YOUR_LICENSE_KEY');
```

## Implementation Patterns

### Basic DocumentEditorContainer Setup
```javascript
import React, { useRef } from 'react';
import { 
  DocumentEditorContainerComponent,
  Toolbar
} from '@syncfusion/ej2-react-documenteditor';

const DocumentEditor = () => {
  const editorRef = useRef(null);

  const serviceUrl = 'https://your-api.com/api/documenteditor/';

  const onCreate = () => {
    // Set default document
    const defaultDocument = {
      sections: [{
        blocks: [{
          paragraphFormat: { textAlignment: 'Left' },
          inlines: [{ text: 'Hello World' }]
        }]
      }]
    };
    editorRef.current.documentEditor.open(JSON.stringify(defaultDocument));
  };

  return (
    <DocumentEditorContainerComponent
      ref={editorRef}
      serviceUrl={serviceUrl}
      height="100vh"
      enableToolbar={true}
      created={onCreate}
    />
  );
};

export default DocumentEditor;
```

### Advanced Configuration with Custom Settings
```javascript
import React, { useRef, useEffect } from 'react';
import { 
  DocumentEditorContainerComponent,
  Toolbar
} from '@syncfusion/ej2-react-documenteditor';

const AdvancedDocumentEditor = () => {
  const editorRef = useRef(null);

  const documentEditorSettings = {
    showRuler: true,
    showStatusBar: true,
    showPropertiesPane: true
  };

  const toolbarItems = [
    'New', 'Open', 'Separator',
    'Undo', 'Redo', 'Separator',
    'Image', 'Table', 'Hyperlink', 'Bookmark', 'TableOfContents', 'Separator',
    'Header', 'Footer', 'PageSetup', 'PageNumber', 'Break', 'Separator',
    'Find', 'Separator',
    'Comments', 'TrackChanges', 'Separator',
    'LocalClipboard', 'RestrictEditing', 'Separator',
    'FormFields', 'UpdateFields'
  ];

  useEffect(() => {
    if (editorRef.current) {
      const editor = editorRef.current.documentEditor;
      
      // Configure document settings
      editor.pageOutline = '#E0E0E0';
      editor.enableComment = true;
      editor.enableTrackChanges = true;
      editor.enableSearch = true;
      editor.enableOptionsPane = true;
      
      // Set user information
      editor.currentUser = 'John Doe';
      editor.userColor = '#FF0000';
    }
  }, []);

  return (
    <DocumentEditorContainerComponent
      ref={editorRef}
      serviceUrl="https://your-api.com/api/documenteditor/"
      height="100vh"
      enableToolbar={true}
      toolbarItems={toolbarItems}
      documentEditorSettings={documentEditorSettings}
      locale="pt-BR"
    />
  );
};

export default AdvancedDocumentEditor;
```

## Document Operations

### Opening Documents

**From File Upload**
```javascript
const handleFileUpload = (event) => {
  const file = event.target.files[0];
  if (file) {
    const reader = new FileReader();
    reader.onload = (e) => {
      const base64 = e.target.result.split(',')[1];
      editorRef.current.documentEditor.open(base64);
    };
    reader.readAsDataURL(file);
  }
};

// In component
<input 
  type="file" 
  accept=".docx,.doc,.rtf,.txt,.sfdt" 
  onChange={handleFileUpload} 
/>
```

**From URL/API**
```javascript
const openDocumentFromUrl = async (documentId) => {
  try {
    const response = await fetch(`/api/documents/${documentId}`);
    const blob = await response.blob();
    
    const reader = new FileReader();
    reader.onload = (e) => {
      const base64 = e.target.result.split(',')[1];
      editorRef.current.documentEditor.open(base64);
    };
    reader.readAsDataURL(blob);
  } catch (error) {
    console.error('Error opening document:', error);
  }
};
```

**From SFDT (Native Format)**
```javascript
const openSFDT = (sfdtContent) => {
  // SFDT is Syncfusion's native JSON format
  editorRef.current.documentEditor.open(sfdtContent);
};
```

### Saving Documents

**Save as DOCX**
```javascript
const saveAsDocx = () => {
  editorRef.current.documentEditor.save('Document', 'Docx');
};
```

**Save as SFDT (for database storage)**
```javascript
const saveAsSFDT = async () => {
  const sfdtContent = editorRef.current.documentEditor.serialize();
  
  // Save to database
  await fetch('/api/documents/save', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      content: sfdtContent,
      title: 'My Document',
      format: 'sfdt'
    })
  });
};
```

**Export as PDF**
```javascript
const exportToPdf = () => {
  editorRef.current.documentEditor.save('Document', 'Pdf');
};
```

**Get Document as Base64**
```javascript
const getDocumentBase64 = () => {
  return new Promise((resolve, reject) => {
    editorRef.current.documentEditor.saveAsBlob('Docx')
      .then((blob) => {
        const reader = new FileReader();
        reader.onload = () => {
          const base64 = reader.result.split(',')[1];
          resolve(base64);
        };
        reader.onerror = reject;
        reader.readAsDataURL(blob);
      });
  });
};
```

## Server-Side Integration

### ASP.NET Core Web API Setup
```csharp
// DocumentEditorController.cs
using Syncfusion.EJ2.DocumentEditor;

[Route("api/[controller]")]
[ApiController]
public class DocumentEditorController : ControllerBase
{
    [HttpPost("Import")]
    public IActionResult Import([FromBody] FileUpload fileUpload)
    {
        if (fileUpload.files != null)
        {
            using (Stream stream = new MemoryStream(Convert.FromBase64String(fileUpload.files)))
            {
                WordDocument document = WordDocument.Load(stream, FormatType.Docx);
                string json = JsonSerializer.Serialize(document);
                document.Dispose();
                return Ok(json);
            }
        }
        return BadRequest();
    }

    [HttpPost("Export")]
    public IActionResult Export([FromBody] SaveParameter saveParameter)
    {
        try
        {
            WordDocument document = WordDocument.LoadString(saveParameter.content, FormatType.Sfdt);
            
            using (MemoryStream stream = new MemoryStream())
            {
                FormatType type = FormatType.Docx;
                if (saveParameter.format == "Pdf")
                    type = FormatType.Pdf;
                
                document.Save(stream, type);
                document.Dispose();
                
                byte[] bytes = stream.ToArray();
                return File(bytes, "application/octet-stream", saveParameter.fileName);
            }
        }
        catch (Exception ex)
        {
            return BadRequest(ex.Message);
        }
    }

    [HttpPost("SpellCheck")]
    public IActionResult SpellCheck([FromBody] SpellCheckJsonData spellCheckData)
    {
        try
        {
            SpellChecker spellChecker = new SpellChecker();
            spellChecker.GetSuggestions(spellCheckData.LanguageID, spellCheckData.TexttoCheck);
            return Ok(spellChecker);
        }
        catch
        {
            return BadRequest();
        }
    }
}

public class FileUpload
{
    public string files { get; set; }
}

public class SaveParameter
{
    public string content { get; set; }
    public string fileName { get; set; }
    public string format { get; set; }
}
```

### Node.js Express Server Setup
```javascript
// server.js
const express = require('express');
const { WordDocument, FormatType } = require('@syncfusion/ej2-documenteditor-server');
const multer = require('multer');
const upload = multer();

const app = express();
app.use(express.json({ limit: '50mb' }));

// Import endpoint
app.post('/api/documenteditor/Import', upload.single('files'), (req, res) => {
  try {
    const buffer = req.file ? req.file.buffer : Buffer.from(req.body.files, 'base64');
    
    WordDocument.load(buffer, FormatType.Docx).then(document => {
      const json = JSON.stringify(document);
      res.send(json);
    });
  } catch (error) {
    res.status(400).send(error.message);
  }
});

// Export endpoint
app.post('/api/documenteditor/Export', (req, res) => {
  try {
    const { content, fileName, format } = req.body;
    
    WordDocument.loadString(content, FormatType.Sfdt).then(document => {
      const formatType = format === 'Pdf' ? FormatType.Pdf : FormatType.Docx;
      
      document.save(formatType).then(buffer => {
        res.setHeader('Content-Type', 'application/octet-stream');
        res.setHeader('Content-Disposition', `attachment; filename=${fileName}`);
        res.send(buffer);
      });
    });
  } catch (error) {
    res.status(400).send(error.message);
  }
});

app.listen(3000, () => {
  console.log('Document Editor server running on port 3000');
});
```

## Collaboration Features

### Track Changes Configuration
```javascript
useEffect(() => {
  if (editorRef.current) {
    const editor = editorRef.current.documentEditor;
    
    // Enable track changes
    editor.enableTrackChanges = true;
    
    // Set current user
    editor.currentUser = 'John Doe';
    editor.userColor = '#FF5733';
    
    // Listen to track changes events
    editor.contentChange = (args) => {
      if (args.source === 'TrackChanges') {
        console.log('Track change detected:', args);
      }
    };
  }
}, []);

// Accept all changes
const acceptAllChanges = () => {
  editorRef.current.documentEditor.revisions.acceptAll();
};

// Reject all changes
const rejectAllChanges = () => {
  editorRef.current.documentEditor.revisions.rejectAll();
};

// Get all revisions
const getRevisions = () => {
  const revisions = editorRef.current.documentEditor.revisions.changes;
  return revisions;
};
```

### Comments Implementation
```javascript
// Insert comment
const insertComment = (commentText) => {
  const editor = editorRef.current.documentEditor;
  
  if (editor.selection.isEmpty) {
    alert('Please select text to comment on');
    return;
  }
  
  editor.editor.insertComment(commentText);
};

// Delete comment
const deleteComment = (commentId) => {
  editorRef.current.documentEditor.editor.deleteComment(commentId);
};

// Get all comments
const getAllComments = () => {
  const comments = editorRef.current.documentEditor.getComments();
  return comments;
};

// Navigate to comment
const navigateToComment = (commentId) => {
  editorRef.current.documentEditor.selection.selectComment(commentId);
};
```

### Document Protection
```javascript
// Restrict editing
const restrictEditing = () => {
  const editor = editorRef.current.documentEditor;
  
  // Set protection type
  editor.editor.enforceProtection('ReadOnly'); // or 'FormFieldsOnly', 'CommentsOnly'
};

// Remove protection
const unprotectDocument = () => {
  editorRef.current.documentEditor.editor.stopProtection();
};

// Check if protected
const isProtected = () => {
  return editorRef.current.documentEditor.documentHelper.isDocumentProtected;
};
```

## Custom Toolbar Implementation

### Add Custom Toolbar Button
```javascript
import { useEffect } from 'react';
import { ItemModel } from '@syncfusion/ej2-navigations';

const CustomToolbarEditor = () => {
  const editorRef = useRef(null);

  useEffect(() => {
    if (editorRef.current) {
      const toolbar = editorRef.current.toolbarModule;
      
      // Custom button item
      const customButton: ItemModel = {
        prefixIcon: 'e-de-ctnr-lock',
        tooltipText: 'Protect Document',
        text: 'Protect',
        id: 'custom_protect',
        click: () => {
          editorRef.current.documentEditor.editor.enforceProtection('ReadOnly');
          alert('Document protected!');
        }
      };
      
      // Add button to toolbar
      toolbar.toolbar.addItems([customButton], toolbar.toolbar.items.length);
    }
  }, []);

  return (
    <DocumentEditorContainerComponent
      ref={editorRef}
      serviceUrl="https://your-api.com/api/documenteditor/"
      height="100vh"
      enableToolbar={true}
    />
  );
};
```

## Form Integration

### React Hook Form Integration
```javascript
import { Controller, useForm } from 'react-hook-form';
import { DocumentEditorContainerComponent } from '@syncfusion/ej2-react-documenteditor';

const DocumentForm = () => {
  const { control, handleSubmit, setValue } = useForm();
  const editorRef = useRef(null);

  const onSubmit = async (data) => {
    // Get document content
    const sfdtContent = editorRef.current.documentEditor.serialize();
    
    // Or get as blob
    const blob = await editorRef.current.documentEditor.saveAsBlob('Docx');
    
    const formData = new FormData();
    formData.append('title', data.title);
    formData.append('document', blob, 'document.docx');
    formData.append('content', sfdtContent);
    
    // Submit to API
    await fetch('/api/documents', {
      method: 'POST',
      body: formData
    });
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <Controller
        name="title"
        control={control}
        render={({ field }) => (
          <input {...field} placeholder="Document Title" />
        )}
      />
      
      <Controller
        name="content"
        control={control}
        render={({ field }) => (
          <DocumentEditorContainerComponent
            ref={editorRef}
            serviceUrl="https://your-api.com/api/documenteditor/"
            height="600px"
            enableToolbar={true}
            contentChange={() => {
              // Update form value on content change
              const content = editorRef.current.documentEditor.serialize();
              field.onChange(content);
            }}
          />
        )}
      />
      
      <button type="submit">Save Document</button>
    </form>
  );
};
```

## Advanced Features

### Mail Merge
```javascript
const performMailMerge = async () => {
  const editor = editorRef.current.documentEditor;
  
  // Data source
  const data = [
    { Name: 'John Doe', Email: 'john@example.com', Position: 'Developer' },
    { Name: 'Jane Smith', Email: 'jane@example.com', Position: 'Designer' }
  ];
  
  // Execute mail merge
  editor.editor.mailMerge.execute(data);
};

// Insert merge field
const insertMergeField = (fieldName) => {
  editorRef.current.documentEditor.editor.insertField(
    `MERGEFIELD ${fieldName} \\* MERGEFORMAT`,
    ''
  );
};
```

### Find and Replace
```javascript
// Find text
const findText = (searchText) => {
  const editor = editorRef.current.documentEditor;
  const searchResults = editor.search.find(searchText);
  return searchResults;
};

// Replace text
const replaceText = (searchText, replaceText) => {
  const editor = editorRef.current.documentEditor;
  
  editor.search.find(searchText);
  editor.search.searchResults.replace(replaceText);
};

// Replace all occurrences
const replaceAll = (searchText, replaceText) => {
  const editor = editorRef.current.documentEditor;
  
  editor.search.findAll(searchText);
  editor.search.searchResults.replaceAll(replaceText);
};
```

### Bookmarks and Hyperlinks
```javascript
// Insert bookmark
const insertBookmark = (bookmarkName) => {
  editorRef.current.documentEditor.editor.insertBookmark(bookmarkName);
};

// Navigate to bookmark
const navigateToBookmark = (bookmarkName) => {
  editorRef.current.documentEditor.selection.selectBookmark(bookmarkName);
};

// Insert hyperlink
const insertHyperlink = (url, displayText) => {
  editorRef.current.documentEditor.editor.insertHyperlink(
    url,
    displayText,
    true // useBookmark
  );
};
```

### Spell Checker
```javascript
const spellCheckSettings = {
  languageID: 1046, // Portuguese Brazil (1033 for English)
  allowSpellCheckAndSuggestion: true,
  enableOptimizedSpellCheck: true
};

<DocumentEditorContainerComponent
  ref={editorRef}
  serviceUrl="https://your-api.com/api/documenteditor/"
  enableSpellCheck={true}
  spellCheckSettings={spellCheckSettings}
/>
```

## Performance Optimization

### Lazy Loading
```javascript
import { lazy, Suspense } from 'react';

const DocumentEditor = lazy(() => 
  import('@syncfusion/ej2-react-documenteditor').then(module => ({
    default: module.DocumentEditorContainerComponent
  }))
);

const App = () => (
  <Suspense fallback={<div>Loading editor...</div>}>
    <DocumentEditor />
  </Suspense>
);
```

### Large Document Handling
```javascript
const documentEditorSettings = {
  // Optimize for large documents
  optimizeSfdt: true,
  
  // Show page breaks
  showHiddenMarks: false,
  
  // Disable layout optimization during editing
  enableLayoutOptimization: false
};

// Use virtual scrolling for better performance
<DocumentEditorContainerComponent
  documentEditorSettings={documentEditorSettings}
  enableVirtualization={true}
/>
```

### Memory Management
```javascript
useEffect(() => {
  return () => {
    // Cleanup on unmount
    if (editorRef.current) {
      editorRef.current.documentEditor.destroy();
    }
  };
}, []);
```

## Common Integration Patterns

### Authentication with Protected Routes
```javascript
const ProtectedDocumentEditor = () => {
  const [user, setUser] = useState(null);
  const editorRef = useRef(null);

  useEffect(() => {
    // Fetch user info
    fetchUserInfo().then(userData => {
      setUser(userData);
      
      if (editorRef.current) {
        editorRef.current.documentEditor.currentUser = userData.name;
        editorRef.current.documentEditor.userColor = userData.color;
      }
    });
  }, []);

  const serviceUrl = `${API_BASE}/documenteditor/`;

  return user ? (
    <DocumentEditorContainerComponent
      ref={editorRef}
      serviceUrl={serviceUrl}
      headers={{
        'Authorization': `Bearer ${user.token}`
      }}
    />
  ) : <div>Loading...</div>;
};
```

### Version Control Integration
```javascript
const DocumentWithVersionControl = ({ documentId }) => {
  const editorRef = useRef(null);
  const [versions, setVersions] = useState([]);

  const saveVersion = async (versionLabel) => {
    const sfdtContent = editorRef.current.documentEditor.serialize();
    
    await fetch('/api/documents/versions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        documentId,
        content: sfdtContent,
        label: versionLabel,
        timestamp: new Date().toISOString()
      })
    });
    
    loadVersions();
  };

  const loadVersion = async (versionId) => {
    const response = await fetch(`/api/documents/versions/${versionId}`);
    const data = await response.json();
    editorRef.current.documentEditor.open(data.content);
  };

  const compareVersions = (version1Id, version2Id) => {
    // Use Document Editor's compare feature
    editorRef.current.documentEditor.showRevisions();
  };

  return (
    <div>
      <div className="version-toolbar">
        <button onClick={() => saveVersion('Draft')}>Save as Draft</button>
        <select onChange={(e) => loadVersion(e.target.value)}>
          {versions.map(v => (
            <option key={v.id} value={v.id}>
              {v.label} - {new Date(v.timestamp).toLocaleString()}
            </option>
          ))}
        </select>
      </div>
      
      <DocumentEditorContainerComponent
        ref={editorRef}
        serviceUrl="/api/documenteditor/"
      />
    </div>
  );
};
```

### Real-Time Collaboration (WebSocket)
```javascript
import io from 'socket.io-client';

const CollaborativeEditor = ({ documentId }) => {
  const editorRef = useRef(null);
  const socketRef = useRef(null);

  useEffect(() => {
    socketRef.current = io('https://your-server.com');
    
    // Join document room
    socketRef.current.emit('join-document', documentId);
    
    // Listen for changes from other users
    socketRef.current.on('document-change', (data) => {
      if (editorRef.current) {
        editorRef.current.documentEditor.open(data.content);
      }
    });
    
    return () => {
      socketRef.current.disconnect();
    };
  }, [documentId]);

  const handleContentChange = (args) => {
    // Broadcast changes to other users
    const content = editorRef.current.documentEditor.serialize();
    socketRef.current.emit('content-change', {
      documentId,
      content,
      user: currentUser
    });
  };

  return (
    <DocumentEditorContainerComponent
      ref={editorRef}
      contentChange={handleContentChange}
      serviceUrl="/api/documenteditor/"
    />
  );
};
```

## Troubleshooting Guide

### Common Issues and Solutions

**Issue: License Error**
```javascript
// Solution: Register license at app entry point
import { registerLicense } from '@syncfusion/ej2-base';
registerLicense('YOUR_SYNCFUSION_LICENSE_KEY');
```

**Issue: Server-side methods not working**
```javascript
// Solution: Ensure serviceUrl is correctly set and server is running
const serviceUrl = process.env.REACT_APP_DOCUMENT_EDITOR_API;

// Verify server endpoints
console.log('Service URL:', serviceUrl);

// Test server connectivity
fetch(`${serviceUrl}/Import`, { method: 'POST' })
  .then(response => console.log('Server status:', response.status))
  .catch(error => console.error('Server error:', error));
```

**Issue: Document not opening**
```javascript
// Solution: Check format and encoding
const openDocumentSafely = (fileOrBase64) => {
  try {
    editorRef.current.documentEditor.open(fileOrBase64);
  } catch (error) {
    console.error('Failed to open document:', error);
    // Try alternative format
    editorRef.current.documentEditor.openBlob(fileOrBase64);
  }
};
```

**Issue: Performance issues with large documents**
```javascript
// Solution: Enable optimizations
const performanceSettings = {
  enableLayoutOptimization: true,
  optimizeSfdt: true,
  enableVirtualization: true,
  showPageBreaks: false
};

<DocumentEditorContainerComponent
  documentEditorSettings={performanceSettings}
/>
```

**Issue: Track changes not persisting**
```javascript
// Solution: Ensure track changes are saved in SFDT format
const saveWithTrackChanges = async () => {
  const sfdtContent = editorRef.current.documentEditor.serialize();
  
  // SFDT preserves all track changes
  await saveToDatabase({
    content: sfdtContent,
    format: 'sfdt',
    hasTrackChanges: true
  });
};
```

## Best Practices

### 1. Document Management
- Always use SFDT format for database storage (preserves all formatting and features)
- Convert to DOCX/PDF only for final export/download
- Implement auto-save with debouncing (every 30-60 seconds)
- Store document metadata separately (title, author, last modified, etc.)

### 2. Server-Side Setup
- Use official Syncfusion server libraries (not custom implementations)
- Implement proper error handling and logging
- Set appropriate file size limits
- Use CDN for static assets

### 3. Security
- Validate all document uploads
- Sanitize HTML content if allowing HTML import
- Implement role-based access control
- Use HTTPS for all API calls
- Never expose API keys in client-side code

### 4. Performance
- Lazy load the Document Editor component
- Use code splitting for large applications
- Implement pagination for document lists
- Cache frequently accessed documents
- Use service workers for offline support

### 5. User Experience
- Show loading indicators during document operations
- Implement auto-save with visual feedback
- Provide keyboard shortcuts
- Add tooltips for toolbar items
- Handle errors gracefully with user-friendly messages

## Integration with Backend Systems

### Laravel Integration Example
```php
// routes/api.php
Route::post('/documenteditor/import', [DocumentEditorController::class, 'import']);
Route::post('/documenteditor/export', [DocumentEditorController::class, 'export']);

// DocumentEditorController.php
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class DocumentEditorController extends Controller
{
    public function import(Request $request)
    {
        $file = $request->file('files') ?? base64_decode($request->input('files'));
        
        // Call Syncfusion service (via external API or library)
        $response = Http::post(env('SYNCFUSION_SERVICE_URL') . '/Import', [
            'files' => base64_encode($file)
        ]);
        
        return response()->json($response->json());
    }
    
    public function export(Request $request)
    {
        $content = $request->input('content');
        $format = $request->input('format', 'Docx');
        $fileName = $request->input('fileName', 'document.docx');
        
        $response = Http::post(env('SYNCFUSION_SERVICE_URL') . '/Export', [
            'content' => $content,
            'format' => $format,
            'fileName' => $fileName
        ]);
        
        return response($response->body())
            ->header('Content-Type', 'application/octet-stream')
            ->header('Content-Disposition', "attachment; filename={$fileName}");
    }
}
```

### Django Integration Example
```python
# views.py
from django.http import JsonResponse, HttpResponse
from django.views.decorators.csrf import csrf_exempt
import requests
import json
import base64

SYNCFUSION_SERVICE_URL = 'https://your-syncfusion-service.com/api/documenteditor'

@csrf_exempt
def import_document(request):
    if request.method == 'POST':
        files = request.FILES.get('files') or base64.b64decode(request.POST.get('files'))
        
        response = requests.post(
            f'{SYNCFUSION_SERVICE_URL}/Import',
            json={'files': base64.b64encode(files).decode()}
        )
        
        return JsonResponse(response.json())

@csrf_exempt
def export_document(request):
    if request.method == 'POST':
        data = json.loads(request.body)
        
        response = requests.post(
            f'{SYNCFUSION_SERVICE_URL}/Export',
            json={
                'content': data['content'],
                'format': data.get('format', 'Docx'),
                'fileName': data.get('fileName', 'document.docx')
            }
        )
        
        return HttpResponse(
            response.content,
            content_type='application/octet-stream',
            headers={'Content-Disposition': f'attachment; filename={data.get("fileName")}'}
        )
```

## Resources

- Official Documentation: https://ej2.syncfusion.com/react/documentation/document-editor/
- API Reference: https://ej2.syncfusion.com/react/documentation/api/document-editor/
- Server-side Dependencies: https://www.npmjs.com/package/@syncfusion/ej2-documenteditor-server
- Sample Applications: https://github.com/syncfusion/ej2-react-samples

## License Information

Syncfusion Document Editor requires a commercial license for production use. Register your license key at application startup:

```javascript
import { registerLicense } from '@syncfusion/ej2-base';
registerLicense('YOUR_LICENSE_KEY_HERE');
```

Free community license available for companies with less than $1M annual revenue.