// See the file "COPYING" in the main distribution directory for copyright.
//
// Log writer for POSTGRES logs.

#ifndef LOGGING_WRITER_POSTGRES_H
#define LOGGING_WRITER_POSTGRES_H

#include "../WriterBackend.h"
#include "libpq-fe.h"

namespace logging { namespace writer {

class Postgres : public WriterBackend {
public:
	Postgres(WriterFrontend* frontend);
	~Postgres();

	static WriterBackend* Instantiate(WriterFrontend* frontend)
		{ return new Postgres(frontend); }

protected:
	virtual bool DoInit(string path, int num_fields,
			    const threading::Field* const* fields);
	virtual bool DoWrite(int num_fields, const threading::Field* const* fields,
			     threading::Value** vals);
	virtual bool DoSetBuf(bool enabled);
	virtual bool DoRotate(string rotated_path, double open,
			      double close, bool terminating);
	virtual bool DoFlush();
	virtual bool DoFinish();

private:
	int AddParams(threading::Value* val, vector<char*> &params, string &call, int currId, bool addcomma);
	string GetTableType(int, int);
	char* FS(const char* format, ...);

	PGconn *conn;
};

}
}


#endif

